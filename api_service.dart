import 'dart:convert'; // Serve per trasformare i dati in JSON
import 'package:http/http.dart' as http; // Il pacchetto per le richieste web
import '../models/app_models.dart'; // Importiamo le nostre classi (Room, Device)

class ApiService {
  // CONFIGURAZIONE IP
  // Se usi l'Emulatore Android, localhost è '10.0.2.2'.
  // Se usi un iPhone fisico o Android fisico, metti l'IP locale del tuo PC (es. '192.168.1.X')
  // Se usi Chrome/Windows app, usa 'localhost'.
  static const String baseUrl = 'http://192.168.1.141/api'; 

  // 1. SCARICA TUTTA LA CASA (GET)
  // Questa funzione recupera Stanze e Dispositivi in un colpo solo
  Future<List<Room>> getHomeConfig(int userId) async {
    final url = Uri.parse('$baseUrl/home-config/$userId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        // Il server ha risposto OK. Decodifichiamo il JSON.
        List<dynamic> data = jsonDecode(response.body);
        
        // Trasformiamo la lista di JSON in una lista di oggetti Room
        return data.map((json) => Room.fromJson(json)).toList();
      } else {
        throw Exception('Errore nel caricamento dati: ${response.statusCode}');
      }
    } catch (e) {
      print("Errore di connessione: $e");
      // Ritorna una lista vuota in caso di errore per non far crashare l'app
      return []; 
    }
  }

  // 2. CREA UNA NUOVA STANZA (POST)
  Future<bool> createRoom(int userId, String name, String icon) async {
    final url = Uri.parse('$baseUrl/rooms');
    
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userId": userId,
          "name": name,
          "icon": icon,
        }),
      );

      return response.statusCode == 200; // Ritorna true se è andato tutto bene
    } catch (e) {
      print("Errore creazione stanza: $e");
      return false;
    }
  }

  // 3. AGGIUNGI UN DISPOSITIVO (POST)
  // Qui inviamo anche gli indirizzi KNX tecnici
  Future<bool> createDevice(int roomId, String name, String type, String knxWrite, String knxRead) async {
    final url = Uri.parse('$baseUrl/devices');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "roomId": roomId,
          "name": name,
          "type": type,
          "knxWrite": knxWrite,
          "knxRead": knxRead,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Errore creazione device: $e");
      return false;
    }
  }

  // 4. INVIA COMANDO DOMOTICO (Accendi/Spegni)
  // id: ID del dispositivo nel database
  // value: 1 (acceso) o 0 (spento), oppure valore dimmer (0-255)
  Future<void> sendCommand(int deviceId, int value) async {
    final url = Uri.parse('$baseUrl/action');

    try {
      // Non aspettiamo la risposta (fire and forget) per rendere la UI veloce
      http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": deviceId, 
          "action": "write", // Parametro extra se serve al backend
          "value": value,
        }),
      );
      print("Comando inviato: Device $deviceId -> Valore $value");
    } catch (e) {
      print("Errore invio comando: $e");
    }
  }
}