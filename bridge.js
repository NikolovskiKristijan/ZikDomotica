const express = require("express");
const WebSocket = require("ws");

const WS_URL = process.env.WS_URL || "ws://localhost:8081";
const PORT = Number(process.env.PORT || 3000);

let ws = null;

// Cache dell'ultimo stato ricevuto
let lastState = null;

/**
 * Normalizza stringhe per match vocale:
 * - lowercase
 * - rimuove a capo / punteggiatura
 * - toglie articoli comuni
 * - compatta spazi
 */
function normalize(s) {
  return (s ?? "")
    .toString()
    .toLowerCase()
    .replace(/[\n\r\t]/g, " ")
    .replace(/[’']/g, " ")
    .replace(/[^\p{L}\p{N} ]/gu, " ") // toglie punteggiatura (unicode)
    .replace(/\b(il|lo|la|i|gli|le|un|uno|una|l)\b/g, " ") // articoli
    .replace(/\s+/g, " ")
    .trim();
}

function tokenSet(s) {
  const parts = normalize(s).split(" ").filter(Boolean);
  return new Set(parts);
}

function connectWs() {
  ws = new WebSocket(WS_URL);

  ws.on("open", () => {
    console.log("✅ Bridge connesso al WS:", WS_URL);
    // prima sync
    sendGetState();
    // refresh periodico
    setInterval(sendGetState, 5000);
  });

  ws.on("message", (msg) => {
    try {
      const obj = JSON.parse(msg.toString());
      // il simulatore manda hello e poi get_state
      if (obj && obj.method === "get_state" && obj.data) {
        lastState = obj;
      }
    } catch {}
  });

  ws.on("close", () => {
    console.log("⚠️ WS chiuso, riconnessione tra 2s...");
    setTimeout(connectWs, 2000);
  });

  ws.on("error", (err) => {
    console.log("❌ Errore WS:", err.message);
  });
}

function sendWs(obj) {
  if (!ws || ws.readyState !== WebSocket.OPEN) {
    throw new Error("WebSocket non connesso");
  }
  ws.send(JSON.stringify(obj));
}

function sendGetState() {
  try {
    sendWs({ method: "get_state", type: "*", majordomo: "bridge" });
  } catch {}
}

/**
 * Trova device con match robusto:
 * 1) match esatto normalizzato
 * 2) match "contiene" (in entrambe le direzioni)
 * 3) match per parole in comune (scoring)
 */
function findDeviceByName(name, room) {
  if (!lastState?.data?.STANZE) return null;

  const rooms = lastState.data.STANZE;

  // se l'utente specifica stanza, cerca lì prima (match stanza normalizzato)
  const roomKey = room
    ? Object.keys(rooms).find((r) => normalize(r) === normalize(room))
    : null;

  const roomList = roomKey ? [roomKey] : Object.keys(rooms);

  // prepara candidati
  const candidates = [];
  for (const r of roomList) {
    const list = rooms[r] || [];
    for (const dev of list) {
      candidates.push({ stanza: r, device: dev, devName: dev?.nome ?? "" });
    }
  }

  const target = normalize(name);

  // 1) esatto
  let hit = candidates.find((c) => normalize(c.devName) === target);
  if (hit) return { stanza: hit.stanza, device: hit.device };

  // 2) contiene
  hit = candidates.find((c) => {
    const dn = normalize(c.devName);
    return dn.includes(target) || target.includes(dn);
  });
  if (hit) return { stanza: hit.stanza, device: hit.device };

  // 3) scoring parole in comune
  const wantedTokens = tokenSet(name);
  let best = null;
  let bestScore = 0;

  for (const c of candidates) {
    const dt = tokenSet(c.devName);
    let score = 0;
    for (const w of wantedTokens) {
      if (dt.has(w)) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }

  // accetta solo se almeno 1 parola in comune
  if (best && bestScore >= 1) return { stanza: best.stanza, device: best.device };

  return null;
}

function findScenarioByName(name) {
  if (!lastState?.data?.SCENARI) return null;
  const target = normalize(name);
  return lastState.data.SCENARI.find((s) => normalize(s.nome) === target) || null;
}

const app = express();
app.use(express.json());

// stato cache (debug)
app.get("/state", (req, res) => {
  if (!lastState) return res.status(503).json({ ok: false, error: "state not ready" });
  res.json(lastState);
});

// accendi/spegni device boolean (DO)
app.post("/device/power", (req, res) => {
  try {
    const name = req.body?.name;
    const room = req.body?.room;
    const on = Boolean(req.body?.on);

    if (!name) return res.status(400).json({ ok: false, error: "missing name" });
    if (!lastState) return res.status(503).json({ ok: false, error: "state not ready" });

    const found = findDeviceByName(name, room);
    if (!found) {
      return res.status(404).json({
        ok: false,
        error: "device not found",
        received: { name, room },
        hint: "Prova un nome più corto o verifica il nome nel /state"
      });
    }

    const dev = found.device;

    // blocco sicurezza: non comandare tapparella con power
    if (dev.codice?.porta === "tapparella") {
      return res.status(400).json({ ok: false, error: "device is a blind, use /blind/set" });
    }

    sendWs({
      method: "set_state",
      type: "*",
      majordomo: "bridge",
      data: {
        codice: dev.codice,
        stato: on
      }
    });

    res.json({ ok: true, stanza: found.stanza, nome: dev.nome, on });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// imposta tapparella 0..100
app.post("/blind/set", (req, res) => {
  try {
    const name = req.body?.name;
    const room = req.body?.room;
    const value = Number(req.body?.value);

    if (!name) return res.status(400).json({ ok: false, error: "missing name" });
    if (Number.isNaN(value)) return res.status(400).json({ ok: false, error: "missing/invalid value" });
    if (!lastState) return res.status(503).json({ ok: false, error: "state not ready" });

    const found = findDeviceByName(name, room);
    if (!found) {
      return res.status(404).json({
        ok: false,
        error: "device not found",
        received: { name, room },
        hint: "Prova un nome più corto o verifica il nome nel /state"
      });
    }

    const dev = found.device;

    if (dev.codice?.porta !== "tapparella") {
      return res.status(400).json({ ok: false, error: "device is not a blind" });
    }

    const clipped = Math.max(0, Math.min(100, value));

    sendWs({
      method: "set_state",
      type: "*",
      majordomo: "bridge",
      data: {
        codice: dev.codice,
        stato: clipped
      }
    });

    res.json({ ok: true, stanza: found.stanza, nome: dev.nome, value: clipped });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

// esegui scenario (endpoint pronto)
app.post("/scene/run", (req, res) => {
  try {
    const name = req.body?.name;
    if (!name) return res.status(400).json({ ok: false, error: "missing name" });
    if (!lastState) return res.status(503).json({ ok: false, error: "state not ready" });

    const sc = findScenarioByName(name);
    if (!sc) return res.status(404).json({ ok: false, error: "scenario not found" });

    res.json({ ok: true, note: "endpoint pronto, manca method PV reale", scenario: sc.nome, codice: sc.codice });
  } catch (e) {
    res.status(500).json({ ok: false, error: e.message });
  }
});

connectWs();

app.listen(PORT, () => {
  console.log("✅ Bridge HTTP su http://localhost:" + PORT);
  console.log("   WS_URL =", WS_URL);
});
