class Device {
  final int id;
  final String name;
  final String type; // 'switch', 'dimmer', 'shutter'
  final String knxWrite;
  final String knxRead;

  Device({required this.id, required this.name, required this.type, required this.knxWrite, required this.knxRead});

  // Factory per convertire il JSON del server in Oggetto Dart
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      knxWrite: json['knx_address_write'],
      knxRead: json['knx_address_read'],
    );
  }
}

class Room {
  final int id;
  final String name;
  final String icon;
  final List<Device> devices; // Lista di dispositivi

  Room({required this.id, required this.name, required this.icon, required this.devices});

  factory Room.fromJson(Map<String, dynamic> json) {
    var deviceList = json['devices'] as List;
    // Mappa la lista JSON in lista di oggetti Device
    List<Device> devices = deviceList.map((i) => Device.fromJson(i)).toList();

    return Room(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
      devices: devices,
    );
  }
}