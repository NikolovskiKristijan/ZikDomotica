import 'package:flutter/material.dart';
import '../models/app_models.dart';

class DeviceCard extends StatefulWidget {
  final Device device;
  const DeviceCard({Key? key, required this.device}) : super(key: key);

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard> {
  bool isOn = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => isOn = !isOn),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOn ? const Color(0xFFFFC107) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.device.type == 'light' ? Icons.lightbulb : Icons.blinds, color: isOn ? Colors.black87 : Colors.grey),
            const SizedBox(height: 4),
            Text(widget.device.name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}