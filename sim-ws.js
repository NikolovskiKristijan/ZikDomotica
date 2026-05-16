/**
 * sim-ws.js  –  Simulatore WebSocket v5
 *
 * Aggiornato per struttura reale Majordomo:
 *  - Formato messaggi: "metodo": "write_state" (come app Flutter)
 *  - STANZE: match per codice.nome (tapparelle) o porta/nodo/azione/nr (digitali)
 *  - CLIMA: struttura sonda + out[] + statoClima
 *  - SCENARI: pulsanti virtuali (porta=PV)
 *  - ANTIFURTO: zone inserimento
 *  - get_state invariato
 */

const WebSocket = require("ws");
const fs        = require("fs");

const STATE_FILE = "./state.json";

function loadState()  { return JSON.parse(fs.readFileSync(STATE_FILE, "utf8")); }
function saveState()  { fs.writeFileSync(STATE_FILE, JSON.stringify(STATE, null, 2)); }

let STATE = loadState();

const wss = new WebSocket.Server({ port: 8081 });

wss.on("connection", (ws) => {
  console.log("🔗 Client connesso");
  ws.send(JSON.stringify({ hello: true }));

  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }

    // ── get_state ─────────────────────────────────────────────────────────────
    if (msg.method === "get_state" || msg.metodo === "get_state") {
      ws.send(JSON.stringify(STATE));
      return;
    }

    // ── write_state / set_state ───────────────────────────────────────────────
    const isWrite = msg.metodo === "write_state" || msg.method === "set_state";
    if (!isWrite) return;

    const dest   = msg.dest || "STANZE";
    const codice = msg.codice || msg.data?.codice;
    const stato  = msg.stato  !== undefined ? msg.stato : msg.data?.stato;
    const nome   = msg.data?.nome;

    // ── STANZE ────────────────────────────────────────────────────────────────
    if (dest === "STANZE") {
      let matched = false;

      for (const room of Object.keys(STATE.data.STANZE)) {
        if (matched) break;
        for (const dev of STATE.data.STANZE[room]) {

          // Tapparelle: match per codice.nome
          if (dev.tipo === 1 && codice) {
            const cn = dev.codice?.nome;
            const matchNome = cn && codice.nome && cn === codice.nome;
            if (matchNome) {
              dev.stato       = stato;
              dev.statoDevice = true;
              matched = true;
              console.log("🪟 [tapparella] " + room + " / " + dev.nome + " → " + stato);
              break;
            }
          }

          // Digitali: match per nome (priorità 1)
          if (!matched && nome && dev.nome &&
              dev.nome.trim().toLowerCase() === String(nome).trim().toLowerCase()) {
            dev.stato       = stato;
            dev.statoDevice = true;
            matched = true;
            console.log("✅ [nome]   " + room + " / " + dev.nome + " → " + stato);
            break;
          }

          // Digitali: match per codice porta/nodo/azione/nr (priorità 2)
          if (!matched && codice && dev.codice && dev.codice.porta !== "tapparella") {
            const c = dev.codice;
            if (
              c.porta  === codice.porta  &&
              String(c.nodo)   === String(codice.nodo)  &&
              c.azione === codice.azione &&
              String(c.nr)     === String(codice.nr)
            ) {
              dev.stato       = stato;
              dev.statoDevice = true;
              matched = true;
              console.log("✅ [codice] " + room + " / " + dev.nome + " → " + stato);
              break;
            }
          }
        }
      }

      if (matched) saveState();
      ws.send(JSON.stringify({ ok: matched }));
      return;
    }

    // ── CLIMA ─────────────────────────────────────────────────────────────────
    if (dest === "CLIMA") {
      const stanza = codice?.stanza;
      const nomeOut = codice?.nome;
      const modo   = codice?.modo;

      if (!stanza || !STATE.data.CLIMA[stanza]) {
        ws.send(JSON.stringify({ ok: false, error: "stanza clima non trovata: " + stanza }));
        return;
      }

      let matched = false;
      const zona = STATE.data.CLIMA[stanza];

      for (const out of zona.out) {
        // Se nomeOut specificato, match preciso; altrimenti aggiorna il primo
        if (nomeOut && out.nome.toLowerCase() !== nomeOut.toLowerCase()) continue;

        const sc = out.statoClima;
        sc.modo = modo ?? 0;

        switch (modo) {
          case 0: // OFF
            sc.testo = "OFF";
            sc.crono = "";
            sc.tTarget = null;
            sc.durata = null;
            sc.tempoResiduo = null;
            out.stato = false;
            break;
          case 1: // ON
            sc.testo = "ON";
            out.stato = true;
            break;
          case 2: // ON PER (durata in ore)
            sc.testo = "ON PER";
            sc.durata = codice.durata ?? null;
            out.stato = true;
            break;
          case 3: // CRONO
            sc.testo = "CRONO";
            sc.crono = codice.crono ?? "";
            out.stato = true;
            break;
          case 4: // TEMPERATURA FISSA
            sc.testo = "T° FISSA";
            sc.tTarget = codice.tTarget ?? null;
            out.stato = true;
            break;
        }

        matched = true;
        console.log("🌡️  [clima] " + stanza + " / " + out.nome +
          " → modo=" + modo + (sc.tTarget ? " tTarget=" + sc.tTarget + "°C" : ""));
        break; // primo match
      }

      if (matched) saveState();
      ws.send(JSON.stringify({ ok: matched }));
      return;
    }

    // ── SCENARI ───────────────────────────────────────────────────────────────
    if (dest === "SCENARI") {
      const nomeScenario = msg.nome_scenario;  // nome preciso inviato dal bridge
      const nodoTarget   = codice?.nodo;

      let found = null;

      // Priorità 1: match per nome esatto (evita problemi con nodi duplicati)
      if (nomeScenario) {
        found = STATE.data.SCENARI.find(
          (sc) => sc.nome && sc.nome.toLowerCase() === String(nomeScenario).toLowerCase()
        );
      }

      // Priorità 2: fallback per nodo (solo se nome non disponibile)
      if (!found && nodoTarget !== undefined) {
        found = STATE.data.SCENARI.find((sc) => sc.codice?.nodo === nodoTarget);
      }

      if (found) {
        console.log("🎬 [scenario] " + found.nome + " → attivato");
        ws.send(JSON.stringify({ ok: true, nome: found.nome }));
      } else {
        ws.send(JSON.stringify({ ok: false, error: "scenario non trovato: " + (nomeScenario || nodoTarget) }));
      }
      return;
    }

    // ── ANTIFURTO ─────────────────────────────────────────────────────────────
    if (dest === "ANTIFURTO") {
      const nodoTarget = codice?.nodo;
      const found = STATE.data.ANTIFURTO.find((a) => a.codice?.nodo === nodoTarget);

      if (found) {
        found.stato = stato ?? 1;
        saveState();
        console.log("🚨 [antifurto] " + found.nome + " → " + found.stato);
        ws.send(JSON.stringify({ ok: true, nome: found.nome }));
      } else {
        ws.send(JSON.stringify({ ok: false, error: "zona antifurto non trovata" }));
      }
      return;
    }

    ws.send(JSON.stringify({ ok: false, error: "dest non gestito: " + dest }));
  });

  ws.on("close", () => console.log("🔌 Client disconnesso"));
});

console.log("🟢 Simulatore WS v5 su ws://localhost:8081");