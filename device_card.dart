import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';

class DeviceCard extends StatefulWidget {
  final Device device;

  const DeviceCard({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  // Stato locale: è acceso o spento?
  bool isOn = false; 
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // NOTA: In un'app reale, qui dovresti leggere lo stato iniziale dal dispositivo
    // Per ora partiamo da spento o gestiamo lo stato tramite Riverpod/Provider
  }

  void _toggleDevice() {
    // 1. OPTIMISTIC UI UPDATE
    // Cambiamo subito l'interfaccia per dare sensazione di velocità estrema
    setState(() {
      isOn = !isOn;
    });

    // 2. Inviamo il comando al backend
    // Se isOn è true -> manda 1, altrimenti 0
    //int valueToSend = isOn ? 1 : 0;
    
    // NOTA: Qui usiamo l'ID del database per identificare il device
    //_apiService.sendCommand(widget.device.id, valueToSend);
    print("Click su ${widget.device.name}. Nuovo stato: $isOn");
  }

  // Helper per scegliere l'icona giusta
  IconData _getIcon() {
    switch (widget.device.type.toLowerCase()) {
      case 'light':
      case 'dimmer':
        return isOn ? Icons.lightbulb : Icons.lightbulb_outline;
      case 'shutter':
        return isOn ? Icons.blinds : Icons.blinds_closed;
      case 'switch':
      default:
        return Icons.power_settings_new;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleDevice,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // Animazione fluida
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          // Se acceso: Colore Giallo/Arancio. Se spento: Grigio scuro (tema dark)
          color: isOn ? Colors.amber[400] : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (isOn) // L'ombra appare solo se è acceso (effetto glow)
              BoxShadow(
                color: Colors.amber.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              )
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ICONA
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOn ? Colors.white.withOpacity(0.3) : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(),
                color: isOn ? Colors.white : Colors.grey[400],
                size: 28,
              ),
            ),
            
            // TESTI
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.device.name,
                  style: TextStyle(
                    color: isOn ? Colors.black87 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isOn ? "ON" : "OFF",
                  style: TextStyle(
                    color: isOn ? Colors.black54 : Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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