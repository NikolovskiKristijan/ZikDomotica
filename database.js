const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./smarthome.db');

db.serialize(() => {
  // Crea tabella Utenti
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT
  )`);

  // Crea tabella Stanze
  db.run(`CREATE TABLE IF NOT EXISTS rooms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    name TEXT,
    icon TEXT,
    FOREIGN KEY(user_id) REFERENCES users(id)
  )`);

  // Crea tabella Dispositivi
  db.run(`CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    room_id INTEGER,
    name TEXT,
    type TEXT,
    knx_address_write TEXT,
    knx_address_read TEXT,
    FOREIGN KEY(room_id) REFERENCES rooms(id)
  )`);
});

module.exports = db;