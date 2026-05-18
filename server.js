const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const axios = require('axios');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(bodyParser.json());

// Stato globale della casa intelligente
let homeStatus = {
    location: "Roma", 
    temperature: "--°C",
    consumption: "1.8 kW",
    activeScenes: [] 
};

// Coordinate di default (Roma) modificate dinamicamente dal GPS o dalla ricerca
let HOME_LAT = 41.8902; 
let HOME_LON = 12.4922;

// Funzione centrale per scaricare il meteo in tempo reale
async function fetchPreciseWeather() {
    try {
        const weatherRes = await axios.get(`https://api.open-meteo.com/v1/forecast?latitude=${HOME_LAT}&longitude=${HOME_LON}&current_weather=true`);
        const currentTemp = weatherRes.data.current_weather.temperature;
        homeStatus.temperature = `${Math.round(currentTemp)}°C`;
        console.log(`[🌤️ METEO] Aggiornato a ${homeStatus.temperature} per ${homeStatus.location} (${HOME_LAT}, ${HOME_LON})`);
    } catch (error) {
        console.log("[METEO ERRORE] Impossibile recuperare i dati meteo:", error.message);
    }
}

// Inizializzazione meteo all'avvio e aggiornamento automatico ogni ora
fetchPreciseWeather();
setInterval(fetchPreciseWeather, 3600000); 

// Database temporaneo in memoria (Mock)
let mockRooms = [
    {
        id: 1, name: "Salotto", icon: "living_room", devices: [
            { id: 1, name: "Luce Centrale", type: "light", knxWrite: "1/0/1", knxRead: "1/1/1", status: 0 },
            { id: 2, name: "Striscia LED", type: "dimmer", knxWrite: "1/0/5", knxRead: "1/1/5", status: 0 }
        ]
    }
];

// 1. GET HOME CONFIG - Ritorna lo stato generale della casa e delle stanze
app.get('/api/home', (req, res) => {
    const randomConsumption = (1.5 + Math.random() * 0.8).toFixed(1);
    homeStatus.consumption = `${randomConsumption} kW`;
    res.json({ info: homeStatus, rooms: mockRooms });
});

// 2. COMMAND - Riceve e aggiorna lo stato dei singoli dispositivi (on/off o dimmer)
app.post('/api/command', (req, res) => {
    const { deviceName, knxAddress, value } = req.body;
    mockRooms.forEach(room => {
        room.devices.forEach(device => {
            if(device.knxWrite === knxAddress) {
                device.status = value;
                console.log(`[KNX COMMAND] ${deviceName} (${knxAddress}) impostato a: ${value}`);
            }
        });
    });
    res.json({ success: true });
});

// 3. SCENE - Attivazione/Disattivazione a interruttore (Toggle) di scenari multipli
app.post('/api/scene', (req, res) => {
    const { sceneName } = req.body;

    if (homeStatus.activeScenes.includes(sceneName)) {
        homeStatus.activeScenes = homeStatus.activeScenes.filter(s => s !== sceneName);
        console.log(`[SCENARIO] Disattivato: ${sceneName}`);
    } else {
        homeStatus.activeScenes.push(sceneName);
        console.log(`[SCENARIO] Attivato: ${sceneName}`);
    }

    // Logica applicativa degli scenari sui dispositivi fisici
    if (homeStatus.activeScenes.includes('Esco')) {
        mockRooms.forEach(room => room.devices.forEach(d => d.status = 0));
        console.log(`[LOGICA SCENARIO] Modalità 'Esco': Spente tutte le luci.`);
    }
    if (homeStatus.activeScenes.includes('Relax')) {
        mockRooms.forEach(room => room.devices.forEach(d => { if(d.type === 'dimmer') d.status = 50; }));
        console.log(`[LOGICA SCENARIO] Modalità 'Relax': Dimmer impostati al 50%.`);
    }

    res.json({ success: true });
});

// 4. LOCATION - Ricerca testuale della città (Geocoding)
app.post('/api/location', async (req, res) => {
    const { city } = req.body;
    try {
        const geoRes = await axios.get(`https://geocoding-api.open-meteo.com/v1/search?name=${encodeURIComponent(city)}&count=1&language=it`);
        
        if (!geoRes.data.results || geoRes.data.results.length === 0) {
            return res.status(404).json({ success: false, message: "Città non trovata" });
        }

        const locationData = geoRes.data.results[0];
        HOME_LAT = locationData.latitude;
        HOME_LON = locationData.longitude;
        homeStatus.location = locationData.name; 

        await fetchPreciseWeather();

        console.log(`[🌍 POSIZIONE MANUALE] Nuova città impostata: ${homeStatus.location}`);
        res.json({ success: true, info: homeStatus });
    } catch (error) {
        console.log("Errore ricerca manuale posizione:", error.message);
        res.status(500).json({ success: false, message: "Errore di ricerca geografica" });
    }
});

// 5. GPS - Riceve le coordinate native dal GPS dello smartphone (Reverse Geocoding)
app.post('/api/gps', async (req, res) => {
    const { lat, lon } = req.body;
    try {
        HOME_LAT = lat;
        HOME_LON = lon;
        
        const geoRes = await axios.get(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=it`);
        
        homeStatus.location = geoRes.data.city || geoRes.data.locality || "Posizione Rilevata";
        
        await fetchPreciseWeather();

        console.log(`[📍 SMARTPHONE GPS] Rilevamento automatico: ${homeStatus.location} (${lat}, ${lon})`);
        res.json({ success: true, info: homeStatus });
    } catch (error) {
        console.log("Errore elaborazione coordinate GPS:", error.message);
        res.status(500).json({ success: false, message: "Errore durante l'elaborazione del GPS" });
    }
});

// 6. ADD ROOMS - Crea una nuova stanza nel database temporaneo
app.post('/api/rooms', (req, res) => {
    const { name, icon } = req.body;
    const newId = mockRooms.length > 0 ? Math.max(...mockRooms.map(r => r.id)) + 1 : 1;
    
    const newRoom = {
        id: newId,
        name: name,
        icon: icon || "home",
        devices: []
    };
    
    mockRooms.push(newRoom);
    console.log(`[STRUTTURA] Creata nuova stanza: ${name} (ID: ${newId})`);
    res.status(201).json({ success: true, room: newRoom });
});

// 7. ADD DEVICES - Aggancia un nuovo dispositivo KNX a una stanza specifica
app.post('/api/devices', (req, res) => {
    const { roomId, name, type, knxWrite, knxRead } = req.body;
    
    const room = mockRooms.find(r => r.id === parseInt(roomId.toString()));
    if (!room) {
        return res.status(404).json({ success: false, message: "Stanza non trovata" });
    }

    let allDevices = [];
    mockRooms.forEach(r => allDevices.push(...r.devices));
    const newDeviceId = allDevices.length > 0 ? Math.max(...allDevices.map(d => d.id)) + 1 : 1;

    const newDevice = {
        id: newDeviceId,
        name: name,
        type: type,
        knxWrite: knxWrite,
        knxRead: knxRead,
        status: 0
    };

    room.devices.push(newDevice);
    console.log(`[STRUTTURA] Nuovo dispositivo aggiunto in ${room.name}: ${name} (ID: ${newDeviceId})`);
    res.status(201).json({ success: true, device: newDevice });
});

// Rotta per il login nel server Node.js
app.post('/api/login', (req, res) => {
    const { username, password } = req.body;

    // Controllo di test (puoi cambiarlo con i dati del tuo database)
    if (username === "alessandro" && password === "1234") {
        console.log("Login effettuato con successo!");
        res.status(200).json({ 
            success: true, 
            userId: 1, // Questo ID viene salvato nella sessione di Flutter
            message: "Benvenuto Alessandro" 
        });
    } else {
        res.status(401).json({ 
            success: false, 
            message: "Credenziali errate" 
        });
    }
});

app.listen(PORT, () => console.log(`🚀 Backend Domotico in ascolto su http://localhost:${PORT}`));