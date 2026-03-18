/**
 * sim-ws.js  –  Simulatore WebSocket v4
 *
 * Fix: set_state si ferma al primo match (per nome),
 *      evitando di aggiornare più device con codici placeholder identici.
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
    if (msg.method === "get_state") {
      ws.send(JSON.stringify(STATE));
      return;
    }

    // ── set_state ─────────────────────────────────────────────────────────────
    if (msg.method === "set_state") {
      const { codice, nome, stato } = msg.data || {};
      let matched = false;

      // Priorità 1: match per nome esatto → si ferma al primo trovato
      if (nome) {
        for (const room of Object.keys(STATE.data.STANZE)) {
          if (matched) break;
          for (const dev of STATE.data.STANZE[room]) {
            if (dev.nome && dev.nome.toLowerCase() === String(nome).toLowerCase()) {
              dev.stato       = stato;
              dev.statoDevice = true;
              matched = true;
              console.log("✅ [nome]   " + room + " / " + dev.nome + " → " + stato);
              break;
            }
          }
        }
      }

      // Priorità 2: match per codice univoco (Modbus reale) → si ferma al primo
      if (!matched && codice) {
        for (const room of Object.keys(STATE.data.STANZE)) {
          if (matched) break;
          for (const dev of STATE.data.STANZE[room]) {
            const c = dev.codice;
            if (c &&
                c.porta  === codice.porta  &&
                c.nodo   === codice.nodo   &&
                c.azione === codice.azione &&
                String(c.nr) === String(codice.nr)) {
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
    }

    // ── set_climate ───────────────────────────────────────────────────────────
    if (msg.method === "set_climate") {
      const { codice, nome, attivo, temperatura_target, modo } = msg.data || {};
      let matched = false;

      for (const room of Object.keys(STATE.data.STANZE)) {
        if (matched) break;
        for (const dev of STATE.data.STANZE[room]) {
          if (dev.tipo !== 2) continue;

          const matchNome   = nome   && dev.nome.toLowerCase() === String(nome).toLowerCase();
          const matchCodice = codice && dev.codice &&
            dev.codice.porta  === codice.porta  &&
            dev.codice.nodo   === codice.nodo   &&
            dev.codice.azione === codice.azione &&
            dev.codice.nr     === codice.nr;

          if (matchNome || matchCodice) {
            if (attivo             !== undefined) dev.attivo             = attivo;
            if (temperatura_target !== undefined) dev.temperatura_target = temperatura_target;
            if (modo               !== undefined) dev.modo               = modo;
            dev.statoDevice = true;
            matched = true;
            console.log("🌡️  [clima] " + room + " / " + dev.nome + " → attivo=" + dev.attivo + " target=" + dev.temperatura_target + "°C");
            break;
          }
        }
      }

      if (matched) saveState();
      ws.send(JSON.stringify({ ok: matched }));
    }
  });

  ws.on("close", () => console.log("🔌 Client disconnesso"));
});

console.log("🟢 Simulatore WS v4 su ws://localhost:8081");