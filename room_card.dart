import 'package:flutter/material.dart';
import '../models/app_models.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const RoomCard({Key? key, required this.room, required this.onTap}) : super(key: key);

  IconData _getIcon(String iconName) {
    if (iconName == 'kitchen') return Icons.kitchen;
    if (iconName == 'bedroom') return Icons.bed;
    return Icons.weekend;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        height: 140,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFFFF007F)]),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Stack(
          children: [
            Positioned(right: -10, bottom: -10, child: Icon(_getIcon(room.icon), size: 120, color: Colors.white10)),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(room.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("${room.devices.length} dispositivi", style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}