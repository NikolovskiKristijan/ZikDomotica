import '../models/app_models.dart';

class ApiService {
  static final List<Room> _mockRooms = [
    Room(id: 1, name: "Salotto", icon: "living_room", devices: [
      Device(id: 1, name: "Luce Centrale", type: "light", knxWrite: "1/0/1", knxRead: "1/1/1"),
      Device(id: 2, name: "Striscia LED", type: "dimmer", knxWrite: "1/0/5", knxRead: "1/1/5"),
    ]),
    Room(id: 2, name: "Cucina", icon: "kitchen", devices: [
      Device(id: 3, name: "Luce Piano", type: "light", knxWrite: "3/0/1", knxRead: "3/1/1"),
    ]),
  ];

  // Nuova funzionalità: SCENARI
  final List<Map<String, dynamic>> scenes = [
    {"name": "Cinema", "icon": "movie", "color": 0xFF673AB7},
    {"name": "Notte", "icon": "bedtime", "color": 0xFF3F51B5},
    {"name": "Esco", "icon": "exit_to_app", "color": 0xFFF44336},
    {"name": "Relax", "icon": "spa", "color": 0xFF4CAF50},
  ];

  static final List<String> systemLogs = [
    "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} - Sistema Avviato",
    "${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} - Connessione Gateway KNX OK (Ping: 12ms)",
  ];

  Future<List<Room>> getHomeConfig(int userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockRooms;
  }

  Future<bool> addRoom(String name, String icon) async {
    _mockRooms.add(Room(id: _mockRooms.length + 1, name: name, icon: icon, devices: []));
    return true;
  }

  Future<bool> addDevice(int roomId, String name, String type, String knxWrite, String knxRead) async {
    var room = _mockRooms.firstWhere((r) => r.id == roomId);
    room.devices.add(Device(id: DateTime.now().millisecondsSinceEpoch, name: name, type: type, knxWrite: knxWrite, knxRead: knxRead));
    return true;
  }
}