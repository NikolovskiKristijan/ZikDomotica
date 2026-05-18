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
  late bool _isOn; 
  final ApiService _apiService = ApiService(); 

  @override
  void initState() {
    super.initState();
    // Inizializza lo stato in base a quello che dice il server
    _isOn = widget.device.status > 0; 
  }

  @override
  void didUpdateWidget(covariant DeviceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se lo stato del dispositivo cambia dal server (es. dopo uno scenario globale),
    // aggiorna immediatamente l'interfaccia grafica
    if (widget.device.status != oldWidget.device.status) {
      setState(() {
        _isOn = widget.device.status > 0;
      });
    }
  }

  // Mappa i vari tipi di dispositivo KNX con le rispettive icone
  IconData _getIcon() {
    switch (widget.device.type) {
      case 'light':
        return Icons.lightbulb;
      case 'dimmer':
        return Icons.brightness_6;
      case 'shutter':
        return Icons.blinds;
      default:
        return Icons.settings_input_component;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isOn = !_isOn; // Inverte lo stato ON/OFF localmente
        });

        // Invia il comando al server Node.js (1 se acceso, 0 se spento)
        int valueToSend = _isOn ? 1 : 0;
        _apiService.sendCommand(widget.device.name, widget.device.knxWrite, valueToSend);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: _isOn ? const Color(0xFF00BFA5) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _isOn ? const Color(0xFF00BFA5) : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: _isOn 
              ? [BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))]
              : [const BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(), 
              color: _isOn ? Colors.white : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Text(
                widget.device.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _isOn ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isOn ? "ACCESO" : "SPENTO",
              style: TextStyle(
                color: _isOn ? Colors.white70 : Colors.grey.shade400,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}