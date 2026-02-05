import 'package:flutter/material.dart';
import '../models/app_models.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;

  const RoomCard({Key? key, required this.room, required this.onTap}) : super(key: key);

  // Helper per convertire la stringa dell'icona (dal DB) in Icona Flutter
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'kitchen': return Icons.kitchen;
      case 'bedroom': return Icons.bed;
      case 'bathroom': return Icons.bathtub;
      case 'living_room': return Icons.weekend;
      case 'office': return Icons.computer;
      default: return Icons.home;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          // Sfumatura elegante scura
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2C2C2E), 
              const Color(0xFF1C1C1E).withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10), // Bordo sottile
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icona in alto a destra
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                _getIconData(room.icon),
                color: Colors.white70,
                size: 32,
              ),
            ),
            
            // Testi in basso
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${room.devices.length} Dispositivi",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}