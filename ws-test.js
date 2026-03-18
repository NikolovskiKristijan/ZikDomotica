const WebSocket = require("ws");

const ws = new WebSocket("ws://localhost:8081");

function send(obj) {
  ws.send(JSON.stringify(obj));
}

ws.on("open", () => {
  console.log("✅ Connesso al WS");

  // 1) chiedo stato
  send({ method: "get_state", type: "*", majordomo: "test" });

  // 2) dopo 1 secondo spengo faro ovest
  setTimeout(() => {
    console.log("➡️ Invio set_state (faro ovest = false)");
    send({
      method: "set_state",
      type: "*",
      majordomo: "test",
      data: {
        codice: { porta: "/dev/ttyS1", nodo: "4", azione: "DO", nr: 0 },
        stato: false
      }
    });
  }, 1000);

  // 3) dopo 2 secondi richiedo stato
  setTimeout(() => {
    console.log("➡️ Richiedo get_state per verificare");
    send({ method: "get_state", type: "*", majordomo: "test" });
  }, 2000);

  // 4) dopo 3 secondi riaccendo (true) e ricontrollo
  setTimeout(() => {
    console.log("➡️ Invio set_state (faro ovest = true)");
    send({
      method: "set_state",
      type: "*",
      majordomo: "test",
      data: {
        codice: { porta: "/dev/ttyS1", nodo: "4", azione: "DO", nr: 0 },
        stato: true
      }
    });
  }, 3000);

  setTimeout(() => {
    console.log("➡️ Richiedo get_state per verificare");
    send({ method: "get_state", type: "*", majordomo: "test" });
  }, 4000);
});

ws.on("message", (msg) => {
  console.log("📩 Ricevuto:");
  console.log(msg.toString());
});

ws.on("error", (err) => {
  console.error("❌ Errore WS:", err);
});
