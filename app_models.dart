class Room {
  final int id;
  final String name;
  final String icon;
  final List<Device> devices;

  Room({required this.id, required this.name, required this.icon, required this.devices});
}

class Device {
  final int id;
  final String name;
  final String type;
  final String knxWrite;
  final String knxRead;

  Device({required this.id, required this.name, required this.type, required this.knxWrite, required this.knxRead});
}