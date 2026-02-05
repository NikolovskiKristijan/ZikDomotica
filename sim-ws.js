// sim-ws.js
const WebSocket = require("ws");
let STATE = require("./state.json");


// Incolla qui il JSON di get_state (solo la parte data, o tutto)

function normalize(s) {
  return (s ?? "")
    .toString()
    .toLowerCase()
    .replace(/\n/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

// Cerca device in STANZE per codice DO
function findDeviceByDoCode(codice) {
  const stanze = STATE.data?.STANZE ?? {};
  for (const room of Object.keys(stanze)) {
    for (const dev of stanze[room]) {
      const c = dev.codice;
      if (
        c &&
        c.porta === codice.porta &&
        String(c.nodo) === String(codice.nodo) &&
        String(c.azione) === String(codice.azione) &&
        Number(c.nr) === Number(codice.nr)
      ) {
        return dev;
      }
    }
  }
  return null;
}

// Cerca tapparella per nome
function findBlindByName(blindName) {
  const stanze = STATE.data?.STANZE ?? {};
  const target = normalize(blindName);
  for (const room of Object.keys(stanze)) {
    for (const dev of stanze[room]) {
      const c = dev.codice;
      if (c && c.porta === "tapparella" && normalize(c.nome) === target) {
        return dev;
      }
    }
  }
  return null;
}

const wss = new WebSocket.Server({ port: 8081 });

wss.on("connection", (ws) => {
  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }

    if (msg.method === "get_state") {
      ws.send(JSON.stringify(STATE));
      return;
    }

    // Comando standard di test: set_state
    if (msg.method === "set_state") {
      const codice = msg.data?.codice;
      const stato = msg.data?.stato;

      if (!codice) {
        ws.send(JSON.stringify({ ok: false, error: "missing codice" }));
        return;
      }

      if (codice.porta === "tapparella") {
        const dev = findBlindByName(codice.nome);
        if (!dev) return ws.send(JSON.stringify({ ok: false, error: "blind not found" }));
        dev.stato = Number(stato);
        ws.send(JSON.stringify({ ok: true }));
        return;
      }

      // DO boolean
      const dev = findDeviceByDoCode(codice);
      if (!dev) return ws.send(JSON.stringify({ ok: false, error: "device not found" }));
      dev.stato = Boolean(stato);
      ws.send(JSON.stringify({ ok: true }));
      return;
    }

    ws.send(JSON.stringify({ ok: false, error: "unknown method", got: msg.method }));
  });

  ws.send(JSON.stringify({ hello: true, note: "simulatore pronto" }));
});

console.log("Simulatore WS su ws://localhost:8081");
