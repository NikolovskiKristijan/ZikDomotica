const db = require('./database');

// 1. Aggiungi una Stanza
app.post('/api/rooms', (req, res) => {
  const { userId, name, icon } = req.body;
  const sql = `INSERT INTO rooms (user_id, name, icon) VALUES (?, ?, ?)`;
  
  db.run(sql, [userId, name, icon], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    res.json({ id: this.lastID, name, icon });
  });
});

// 2. Aggiungi un Dispositivo
app.post('/api/devices', (req, res) => {
  const { roomId, name, type, knxWrite, knxRead } = req.body;
  
  const sql = `INSERT INTO devices (room_id, name, type, knx_address_write, knx_address_read) VALUES (?, ?, ?, ?, ?)`;
  
  db.run(sql, [roomId, name, type, knxWrite, knxRead], function(err) {
    if (err) return res.status(500).json({ error: err.message });
    
    // IMPORTANTE: Ora che abbiamo un nuovo indirizzo nel DB, 
    // dobbiamo dire al modulo KNX di "monitorarlo" se necessario, 
    // oppure aggiornare la cache degli stati.
    console.log(`Nuovo dispositivo aggiunto: ${name} -> W:${knxWrite} / R:${knxRead}`);
    
    res.json({ id: this.lastID, success: true });
  });
});

// Endpoint per scaricare l'intera casa di un utente
app.get('/api/home-config/:userId', (req, res) => {
  const userId = req.params.userId;

  // 1. Prendi tutte le stanze dell'utente
  const sqlRooms = "SELECT * FROM rooms WHERE user_id = ?";
  
  db.all(sqlRooms, [userId], (err, rooms) => {
    if (err) return res.status(500).json({ error: err.message });

    // Se non ci sono stanze, ritorna array vuoto
    if (rooms.length === 0) return res.json([]);

    // 2. Prendi TUTTI i dispositivi di quelle stanze
    // (Uso una query IN (...) per efficienza, ma per l'esame basta prendere tutto e filtrare)
    const sqlDevices = "SELECT * FROM devices"; 

    db.all(sqlDevices, [], (err, allDevices) => {
      if (err) return res.status(500).json({ error: err.message });

      // 3. LA MAGIA: Unire Stanze e Dispositivi (Data Mapping)
      // Per ogni stanza, cerchiamo i dispositivi che le appartengono
      const homeStructure = rooms.map(room => {
        return {
          ...room, // Copia dati stanza (id, nome, icona)
          devices: allDevices.filter(device => device.room_id === room.id) // Inserisci array dispositivi
        };
      });

      // Ritorna la struttura nidificata perfetta per Flutter
      res.json(homeStructure);
    });
  });
});