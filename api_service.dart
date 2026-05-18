import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_models.dart';

class ApiService {
  // Pattern Singleton
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // IP del tuo PC configurato e verificato tramite ipconfig
  final String baseUrl = 'http://192.168.1.141:3000/api'; 

  // Gestione della sessione utente
  int? loggedUserId; 

  String currentInfoLocation = "Roma";
  String currentInfoTemperature = "--°C";
  String currentInfoConsumption = "1.8 kW";
  List<String> currentActiveScenes = [];

  final List<Map<String, dynamic>> scenes = [
    {'name': 'Relax', 'icon': 'spa', 'color': 0xFF9C27B0},
    {'name': 'Cinema', 'icon': 'movie', 'color': 0xFFE91E63},
    {'name': 'Notte', 'icon': 'bedtime', 'color': 0xFF3F51B5},
    {'name': 'Esco', 'icon': 'exit_to_app', 'color': 0xFFFF5722},
  ];

  // NUOVA: Funzione per autenticare l'utente e salvare l'ID in sessione
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"username": username, "password": password}),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> body = json.decode(response.body);
        // Salva l'ID utente restituito dal database (es. 1, 2, ecc.)
        loggedUserId = body['userId']; 
        return true;
      }
    } catch (e) {
      print("Errore durante il login: $e");
    }
    return false;
  }

  Future<List<Room>> getHomeConfig(int userId) async {
    try {
      // Se l'utente si è loggato usa il suo ID sessione, altrimenti usa il fallback passato dalla Home
      final int activeId = loggedUserId ?? userId;

      final response = await http.get(Uri.parse('$baseUrl/home?userId=$activeId'));
      if (response.statusCode == 200) {
        Map<String, dynamic> body = json.decode(response.body);
        
        currentInfoLocation = body['info']['location'] ?? "Roma";
        currentInfoTemperature = body['info']['temperature'] ?? "--°C";
        currentInfoConsumption = body['info']['consumption'] ?? "1.8 kW";
        
        if (body['info']['activeScenes'] != null) {
          currentActiveScenes = List<String>.from(body['info']['activeScenes']);
        } else {
          currentActiveScenes = [];
        }

        List<dynamic> roomsJson = body['rooms'];
        return roomsJson.map((item) => Room.fromJson(item)).toList();
      }
    } catch (e) {
      print("Errore durante getHomeConfig: $e");
    }
    return [];
  }

  Future<void> sendCommand(String deviceName, String knxAddress, int value) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/command'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "deviceName": deviceName,
          "knxAddress": knxAddress,
          "value": value
        }),
      );
    } catch (e) {
      print("Errore durante l'invio del comando: $e");
    }
  }

  Future<void> activateScene(String sceneName) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/scene'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"sceneName": sceneName}),
      );
    } catch (e) {
      print("Errore durante l'attivazione dello scenario: $e");
    }
  }

  Future<void> updateLocationOnServer(String city) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/location'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"city": city}),
      );
    } catch (e) {
      print("Errore durante il cambio manuale di posizione: $e");
    }
  }

  Future<void> sendGpsToServer(double lat, double lon) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/gps'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"lat": lat, "lon": lon}),
      );
    } catch (e) {
      print("Errore durante l'invio delle coordinate GPS al server: $e");
    }
  }

  Future<bool> addRoom(String name, String icon) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/rooms'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "userId": loggedUserId ?? 1, // Associa la stanza all'utente attivo
          "name": name, 
          "icon": icon
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Errore durante l'aggiunta della stanza: $e");
      return false;
    }
  }

  Future<bool> addDevice(int roomId, String name, String type, String knxWrite, String knxRead) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "roomId": roomId,
          "name": name,
          "type": type,
          "knxWrite": knxWrite,
          "knxRead": knxRead
        }),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Errore durante l'aggiunta del dispositivo: $e");
      return false;
    }
  }
}