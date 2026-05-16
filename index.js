"use strict";

const https = require("https");
const { URL } = require("url");

const BRIDGE_BASE_URL = "https://submedian-tristin-frameless.ngrok-free.dev";
const DEBUG_MODE = false;

const BRIDGE_TIMEOUT_MS = 4500;
const httpsAgent = new https.Agent({ keepAlive: true });

/* ----------------------------- Alexa helpers ----------------------------- */

function speak(text, { endSession = false, reprompt = null, sessionAttributes = null } = {}) {
  const response = {
    outputSpeech: { type: "PlainText", text },
    shouldEndSession: Boolean(endSession),
  };
  if (!endSession && reprompt) {
    response.reprompt = { outputSpeech: { type: "PlainText", text: reprompt } };
  }
  const out = { version: "1.0", response };
  if (sessionAttributes) out.sessionAttributes = sessionAttributes;
  return out;
}

function slotValue(slot) {
  return String(slot?.value ?? "").trim();
}

/* --------------------------- Bridge HTTP helper -------------------------- */

function postJson(path, body) {
  return new Promise((resolve, reject) => {
    const base = new URL(BRIDGE_BASE_URL);
    const port = base.port ? Number(base.port) : base.protocol === "http:" ? 80 : 443;
    const payload = JSON.stringify(body ?? {});

    const options = {
      protocol: base.protocol,
      hostname: base.hostname,
      port,
      method: "POST",
      path,
      agent: httpsAgent,
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(payload),
        "User-Agent": "alexa-skill-bridge/1.0",
        "x-api-key": "ZIK_SECRET_2026",
      },
      timeout: BRIDGE_TIMEOUT_MS,
    };

    if (DEBUG_MODE) console.log("bridge POST", base.origin + path, body);

    const req = https.request(options, (res) => {
      let raw = "";
      res.on("data", (chunk) => {
        raw += chunk;
        if (raw.length > 1000000) { req.destroy(); reject(new Error("Risposta bridge troppo grande")); }
      });
      res.on("end", () => {
        let json = null;
        try { json = raw ? JSON.parse(raw) : null; } catch {}
        const ok = res.statusCode >= 200 && res.statusCode < 300;
        if (!ok) {
          const msg = (json && (json.error || json.message)) || (raw && raw.slice(0, 300)) || "HTTP " + res.statusCode;
          const err = new Error(msg);
          err.statusCode = res.statusCode;
          err.payload = json ?? raw;
          return reject(err);
        }
        resolve(json ?? raw);
      });
    });

    req.on("timeout", () => req.destroy(new Error("Timeout bridge")));
    req.on("error", (err) => reject(err));
    req.write(payload);
    req.end();
  });
}

/* ------------------------ Blind query parsing ------------------------ */

function parseBlindQuery(q) {
  const s = String(q || "").toLowerCase().replace(/[.,;:!?]/g, " ").replace(/\s+/g, " ").trim();

  const m = s.match(/\b(100|[0-9]{1,2})\b\s*(%|per cento|percento)?\b/i);
  let percent = null;
  if (m) {
    const n = Number(m[1]);
    if (!Number.isNaN(n)) percent = n;
  }

  let name = s;
  name = name.replace(/\b(al|alla|a|ai|alle|del|della|dei|delle)\s+(100|[0-9]{1,2})\b(\s*(%|per cento|percento))?/gi, " ");
  name = name.replace(/\b(100|[0-9]{1,2})\b(\s*(%|per cento|percento))?/gi, " ");
  name = name.replace(/\b(imposta|metti|porta|regola|tapparella|tapparelle|scelgo)\b/gi, " ");
  name = name.replace(/\s+/g, " ").trim();

  return { name, percent };
}

/* ------------------- Climate query parsing ------------------- */

function parseClimateQuery(q) {
  // Normalizza: rimuovi punteggiatura E simbolo gradi °
  const s = String(q || "").toLowerCase()
    .replace(/°/g, " ")
    .replace(/[.,;:!?]/g, " ")
    .replace(/\s+/g, " ").trim();

  // Estrai temperatura (es. "21", "20.5")
  const mTemp = s.match(/\b([0-9]{1,2}(?:[.,][05])?)\s*(?:gradi?)?\b/i);
  let temp = null;
  if (mTemp) {
    const n = parseFloat(mTemp[1].replace(",", "."));
    if (!isNaN(n) && n >= 5 && n <= 40) temp = n;
  }

  // Estrai durata (es. "2 ore", "3 ore")
  const mDurata = s.match(/\b([1-5])\s*or[ae]\b/i);
  const durata = mDurata ? parseInt(mDurata[1]) : null;

  // Estrai modo (on/off)
  const isOff = /\b(off|spegni|spento)\b/i.test(s);
  const isOn  = /\b(on|accendi|acceso)\b/i.test(s);

  // Isola la zona rimuovendo tutte le parole chiave
  let zone = s;
  zone = zone.replace(/\b(temperatura|termostato|riscaldamento|raffrescamento|clima|gradi?|on|off|acceso|spento|a|al|il|la|lo|del|della|in|nel|nella|per|or[ae]|h)\b/gi, " ");
  zone = zone.replace(/\b[0-9]{1,2}(?:[.,][05])?\b/g, " ");
  zone = zone.replace(/\s+/g, " ").trim();

  return { zone: zone || null, temp, durata, isOff, isOn };
}

/* ------------------- Disambiguation helpers ------------------- */

function pickOptionFromUserChoice(options, choiceRaw) {
  const choice = String(choiceRaw || "").toLowerCase().trim();
  if (!choice) return null;
  let best = null, bestScore = 0;
  for (const opt of options) {
    const name = String(opt || "").toLowerCase();
    const words = choice.split(/\s+/).filter(Boolean);
    let score = 0;
    for (const w of words) {
      if (w.length >= 2 && name.includes(w)) score++;
    }
    if (score > bestScore) { bestScore = score; best = opt; }
  }
  return bestScore >= 1 ? best : null;
}

function humanizeBlindOptions(options) {
  const lower = options.map((x) => String(x).toLowerCase());
  const allStartWithCucina = lower.every((x) => x.startsWith("cucina "));
  if (allStartWithCucina) return options.map((x) => String(x).replace(/^cucina\s+/i, ""));
  return options;
}

/* ── Helpers disambiguation pending ──────────────────────────── */

function askPending(sess) {
  const pending  = sess.pendingBlind;
  const readable = humanizeBlindOptions(pending.options).join(", ");
  return speak("Ho trovato: " + readable + ". Di scelgo seguito dal nome. Ad esempio: scelgo portafinestra.", {
    endSession: false,
    reprompt: "Di scelgo seguito dal nome, ad esempio: scelgo finestra sud.",
    sessionAttributes: sess,
  });
}

async function resolvePending(sess, rawText) {
  const pending = sess.pendingBlind;
  const picked  = pickOptionFromUserChoice(pending.options, rawText);
  if (!picked) return askPending(sess);
  await postJson("/blind/set", { name: picked, value: pending.value });
  const newSess = Object.assign({}, sess);
  delete newSess.pendingBlind;
  return speak("Ok. Imposto " + picked + " al " + pending.value + " per cento.", {
    endSession: false,
    sessionAttributes: newSess,
  });
}

/* ------------------------------- Intent handlers ------------------------------ */

async function handleLaunch() {
  return speak(
    "Dimmi un comando: accendi faro ovest, imposta tapparella cucina al 30 per cento, temperatura soggiorno 21 gradi, oppure scenario esterne on.",
    { endSession: false, reprompt: "Dimmi ad esempio: accendi faro ovest." }
  );
}

async function handleHelp() {
  return speak(
    "Puoi dire: accendi o spegni un dispositivo. Imposta una tapparella al 30 per cento. Temperatura soggiorno 21 gradi per accendere il riscaldamento. Riscaldamento on o off per una zona. Scenario seguito dal nome. Antifurto on o off.",
    { endSession: false, reprompt: "Prova: accendi faro ovest." }
  );
}

async function handleStop() {
  return speak("Ok.", { endSession: true });
}

async function handlePower(intentName, req, event) {
  const sess    = event.session?.attributes || {};
  const pending = sess.pendingBlind || null;
  if (pending && pending.options?.length) {
    return await resolvePending(sess, slotValue(req.intent?.slots?.query));
  }
  const query = slotValue(req.intent?.slots?.query);
  if (!query) return speak("Quale dispositivo?", { endSession: false, reprompt: "Dimmi il nome del dispositivo." });

  const on = intentName === "TurnOnIntent";

  const result = await postJson("/device/power", { name: query, on });

  // Dispositivo già nello stato richiesto
  if (result && result.already) {
    return speak(query + " è già " + (on ? "acceso." : "spento."), { endSession: false });
  }

  return speak((on ? "Accendo " : "Spengo ") + query + ".", { endSession: false });
}

async function handleOpenCloseBlind(intentName, req, event) {
  const sess    = event.session?.attributes || {};
  const pending = sess.pendingBlind || null;
  const action  = intentName === "OpenBlindIntent" ? "Apro" : "Chiudo";
  const value   = intentName === "OpenBlindIntent" ? 100 : 0;

  if (pending && pending.options?.length) {
    return await resolvePending(sess, slotValue(req.intent?.slots?.query));
  }

  const query = slotValue(req.intent?.slots?.query);
  if (!query) return speak("Quale tapparella?", { endSession: false, reprompt: "Dimmi il nome della tapparella." });

  try {
    await postJson("/blind/set", { name: query, value });
    return speak(action + " " + query + ".", { endSession: false });
  } catch (e) {
    if (e.statusCode === 409 && e.payload && Array.isArray(e.payload.options)) {
      const options  = e.payload.options.map((o) => o?.nome).filter(Boolean);
      const readable = humanizeBlindOptions(options).join(", ");
      const newSess  = Object.assign({}, sess, { pendingBlind: { value, options } });
      return speak("Ho trovato: " + readable + ". Di scelgo seguito dal nome. Ad esempio: scelgo portafinestra.", {
        endSession: false,
        reprompt: "Di scelgo seguito dal nome, ad esempio: scelgo finestra sud.",
        sessionAttributes: newSess,
      });
    }
    throw e;
  }
}

async function handleSetBlindPercent(req, event) {
  const sess    = event.session?.attributes || {};
  const pending = sess.pendingBlind || null;

  if (pending && pending.options?.length) {
    const choiceText = slotValue(req.intent?.slots?.choice) || slotValue(req.intent?.slots?.query) || "";
    return await resolvePending(sess, choiceText);
  }

  const rawQuery = slotValue(req.intent?.slots?.query);

  // Intercetta clima finito qui per errore
  const climateKW = ["temperatura", "termostato", "riscaldamento", "raffrescamento", "clima", "gradi"];
  if (climateKW.some((k) => rawQuery.toLowerCase().includes(k))) {
    return await handleClimate("SetTemperatureIntent", req);
  }

  // Intercetta scenari finiti qui per errore
  const scenarioKW = ["scenario", "attiva", "esegui", "lancia"];
  if (scenarioKW.some((k) => rawQuery.toLowerCase().includes(k))) {
    return await handleScenario(req);
  }

  if (!rawQuery) {
    return speak("Quale tapparella e a che percentuale?", {
      endSession: false,
      reprompt: "Dimmi ad esempio: imposta tapparella cucina al 30 per cento.",
    });
  }

  const parsed  = parseBlindQuery(rawQuery);
  if (!parsed.name) return speak("Quale tapparella?", { endSession: false });
  if (parsed.percent === null) return speak("A che percentuale?", { endSession: false });

  const clipped = Math.max(0, Math.min(100, parsed.percent));

  try {
    await postJson("/blind/set", { name: parsed.name, value: clipped });
    return speak("Imposto " + parsed.name + " al " + clipped + " per cento.", { endSession: false });
  } catch (e) {
    if (e.statusCode === 409 && e.payload && Array.isArray(e.payload.options)) {
      const options  = e.payload.options.map((o) => o && o.nome).filter(Boolean);
      const newSess  = Object.assign({}, sess, { pendingBlind: { value: clipped, options } });
      const readable = humanizeBlindOptions(options).join(", ");
      return speak("Ho trovato: " + readable + ". Di scelgo seguito dal nome. Ad esempio: scelgo portafinestra.", {
        endSession: false,
        reprompt: "Di scelgo seguito dal nome, ad esempio: scelgo finestra sud.",
        sessionAttributes: newSess,
      });
    }
    throw e;
  }
}

async function handleFallback(req, event) {
  const sess    = event.session?.attributes || {};
  const pending = sess.pendingBlind || null;
  if (pending && pending.options?.length) {
    return await resolvePending(sess, slotValue(req.intent?.slots?.query) || "");
  }
  return speak("Non ho capito. Prova: accendi faro ovest. Oppure: imposta tapparella cucina al 30 per cento.", {
    endSession: false,
    reprompt: "Prova: accendi faro ovest.",
  });
}

/* ----------------------------- Climate handler ----------------------------- */

async function handleClimate(intentName, req) {
  const query = slotValue(req.intent?.slots?.query);

  if (!query) {
    return speak("Dimmi zona e comando. Ad esempio: temperatura soggiorno 21 gradi.", {
      endSession: false,
      reprompt: "Dimmi ad esempio: temperatura soggiorno 21 gradi.",
    });
  }

  const parsed = parseClimateQuery(query);

  if (!parsed.zone) {
    return speak("Quale zona? Ad esempio: soggiorno o cucina.", {
      endSession: false,
      reprompt: "Dimmi il nome della zona.",
    });
  }

  const body = { name: parsed.zone };

  // ── Determina modo ────────────────────────────────────────────────────────

  // OFF → modo 0
  const wantsOff = intentName === "TurnOffClimateIntent" || parsed.isOff;
  if (wantsOff && parsed.temp === null && parsed.durata === null) {
    body.modo = 0;
    body.on   = false;
    const res = await postJson("/climate/set", body);
    if (res && res.already) return speak("Il riscaldamento in " + parsed.zone + " è già spento.", { endSession: false });
    return speak("Ok, spengo il riscaldamento in " + parsed.zone + ".", { endSession: false });
  }

  // ON PER N ORE → modo 2
  if (parsed.durata !== null) {
    body.modo   = 2;
    body.durata = parsed.durata;
    if (parsed.temp !== null) body.temperature = parsed.temp;
    const res = await postJson("/climate/set", body);
    if (res && res.already) return speak("Il riscaldamento in " + parsed.zone + " è già attivo.", { endSession: false });
    const msg = parsed.temp !== null
      ? "Ok, accendo il riscaldamento in " + parsed.zone + " per " + parsed.durata + " ore a " + parsed.temp + " gradi."
      : "Ok, accendo il riscaldamento in " + parsed.zone + " per " + parsed.durata + " ore.";
    return speak(msg, { endSession: false });
  }

  // TEMPERATURA FISSA → modo 4
  if (parsed.temp !== null) {
    body.modo        = 4;
    body.temperature = parsed.temp;
    const res = await postJson("/climate/set", body);
    if (res && res.already) return speak("Il riscaldamento in " + parsed.zone + " è già impostato a " + parsed.temp + " gradi.", { endSession: false });
    return speak("Ok, imposto " + parsed.zone + " a " + parsed.temp + " gradi.", { endSession: false });
  }

  // ON semplice → modo 1
  body.modo = 1;
  body.on   = true;
  const res = await postJson("/climate/set", body);
  if (res && res.already) return speak("Il riscaldamento in " + parsed.zone + " è già acceso.", { endSession: false });
  return speak("Ok, accendo il riscaldamento in " + parsed.zone + ".", { endSession: false });
}

/* ----------------------------- Scenario handler ----------------------------- */

async function handleScenario(req) {
  const query = slotValue(req.intent?.slots?.query);

  if (!query) {
    return speak("Quale scenario vuoi attivare?", {
      endSession: false,
      reprompt: "Dimmi il nome dello scenario, ad esempio: esterne on.",
    });
  }

  // Rimuovi parole trigger dal nome scenario
  let name = query.toLowerCase()
    .replace(/\b(scenario|attiva|esegui|lancia|avvia)\b/gi, " ")
    .replace(/\s+/g, " ").trim();

  await postJson("/scenario/run", { name });
  return speak("Ok, attivo " + name + ".", { endSession: false });
}

/* ----------------------------- Antifurto handler ----------------------------- */

async function handleAntifurto(intentName, req) {
  const query = slotValue(req.intent?.slots?.query);

  const zone = query
    ? query.toLowerCase()
        .replace(/\b(antifurto|allarme|zona|attiva|inserisci|disinserisci|off|on)\b/gi, " ")
        .replace(/\s+/g, " ").trim()
    : "generale";

  const stato  = intentName === "AntifurtoOnIntent" ? 1 : 0;
  const azione = stato === 1 ? "Inserisco" : "Disinserisco";

  const res = await postJson("/antifurto/set", { name: zone || "generale", stato });
  if (res && res.already) {
    return speak("L'allarme " + (zone || "generale") + " è già " + (stato === 1 ? "inserito." : "disinserito."), { endSession: false });
  }
  return speak(azione + " l'allarme " + (zone || "generale") + ".", { endSession: false });
}

/* --------------------------------- Lambda --------------------------------- */

exports.handler = async (event) => {
  let response = null;

  try {
    const req = event?.request;

    if (DEBUG_MODE) {
      console.log("REQ_TYPE:", req?.type);
      console.log("INTENT:", req?.intent?.name || "");
      console.log("SLOTS:", JSON.stringify(req?.intent?.slots || {}, null, 0));
    }

    if (!req?.type) response = speak("Richiesta non valida.", { endSession: true });
    else if (req.type === "LaunchRequest") response = await handleLaunch();
    else if (req.type === "SessionEndedRequest") response = { version: "1.0", response: { shouldEndSession: true } };
    else if (req.type !== "IntentRequest") response = speak("Non ho capito.", { endSession: false });
    else {
      const intentName = req.intent?.name || "";

      switch (intentName) {
        case "AMAZON.HelpIntent":
          response = await handleHelp();
          break;
        case "AMAZON.StopIntent":
        case "AMAZON.CancelIntent":
          response = await handleStop();
          break;
        case "AMAZON.FallbackIntent":
          response = await handleFallback(req, event);
          break;
        case "TurnOnIntent":
        case "TurnOffIntent":
          response = await handlePower(intentName, req, event);
          break;
        case "OpenBlindIntent":
        case "CloseBlindIntent":
          response = await handleOpenCloseBlind(intentName, req, event);
          break;
        case "SetBlindPercentIntent":
          response = await handleSetBlindPercent(req, event);
          break;
        case "SetTemperatureIntent":
        case "TurnOnClimateIntent":
        case "TurnOffClimateIntent":
        case "ClimaIntent":
          response = await handleClimate(intentName, req);
          break;
        case "ScenarioIntent":
          response = await handleScenario(req);
          break;
        case "AntifurtoOnIntent":
        case "AntifurtoOffIntent":
          response = await handleAntifurto(intentName, req);
          break;
        default:
          response = speak("Comando non riconosciuto.", { endSession: false });
      }
    }
  } catch (e) {
    console.log("ERROR:", e && e.stack ? e.stack : String(e));
    response = speak("Ho avuto un problema nel contattare il sistema. Riprova tra poco.", { endSession: true });
  }

  if (DEBUG_MODE) console.log("RESPONSE:", JSON.stringify(response, null, 0));

  if (response && response.response && Object.prototype.hasOwnProperty.call(response.response, "type")) {
    delete response.response.type;
  }

  return response;
};