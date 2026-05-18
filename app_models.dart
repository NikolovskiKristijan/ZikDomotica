class Device {
  final int id;
  final String name;
  final String type;
  final String knxWrite;
  final String knxRead;
  int status;

  Device({
    required this.id,
    required this.name,
    required this.type,
    required this.knxWrite,
    required this.knxRead,
    required this.status,
  });

  // Mappa i dati JSON che arrivano dal server Node.js in un oggetto Device di Flutter
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      knxWrite: json['knxWrite'] ?? '',
      knxRead: json['knxRead'] ?? '',
      status: json['status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'knxWrite': knxWrite,
      'knxRead': knxRead,
      'status': status,
    };
  }
}

class Room {
  final int id;
  final String name;
  final String icon;
  final List<Device> devices;

  Room({
    required this.id,
    required this.name,
    required this.icon,
    required this.devices,
  });

  // Mappa i dati JSON della stanza e converte in automatico anche la lista di dispositivi interni
  factory Room.fromJson(Map<String, dynamic> json) {
    var list = json['devices'] as List? ?? [];
    List<Device> deviceList = list.map((i) => Device.fromJson(i)).toList();

    return Room(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'home',
      devices: deviceList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'devices': devices.map((d) => d.toJson()).toList(),
    };
  }
}