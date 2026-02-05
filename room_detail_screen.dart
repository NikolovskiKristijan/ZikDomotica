import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../widgets/device_card.dart';
import 'add_device_screen.dart'; // Creeremo questa poi per aggiungere device

class RoomDetailScreen extends StatefulWidget {
  final Room room;

  const RoomDetailScreen({Key? key, required this.room}) : super(key: key);

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  // Nota: In un'app reale qui useresti setState per aggiornare la lista se aggiungi un device
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          // Bottone "+" per aggiungere dispositivi in questa stanza
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Naviga alla pagina di aggiunta (la faremo allo step successivo)
              // Navigator.push(...);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: widget.room.devices.isEmpty 
            ? _buildEmptyState() 
            : _buildGrid(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.device_unknown, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("Nessun dispositivo qui.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: widget.room.devices.length,
      itemBuilder: (context, index) {
        return DeviceCard(device: widget.room.devices[index]);
      },
    );
  }
}