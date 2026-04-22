import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../widgets/device_card.dart';
import 'add_device_screen.dart'; // Assicurati di avere questo import

class RoomDetailScreen extends StatefulWidget {
  final Room room;
  const RoomDetailScreen({Key? key, required this.room}) : super(key: key);

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  double _brightness = 50.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.power_settings_new, color: Color(0xFFFF007F)),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Master OFF: Tutta la stanza spenta"), behavior: SnackBarBehavior.floating)
            ),
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          // Hub Centrale
          Container(
            height: 100, width: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(Icons.water_drop, color: Colors.blue, size: 20),
                Text("45%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Umidità", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ]
            ),
          ),
          const SizedBox(height: 20),
          
          // Slider Luminosità
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Dimmer Stanza", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text("${_brightness.toInt()}%", style: const TextStyle(fontSize: 12)),
                ]),
                Slider(
                  value: _brightness,
                  min: 0, max: 100,
                  activeColor: const Color(0xFFFFC107),
                  onChanged: (val) => setState(() => _brightness = val),
                ),
              ],
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, 
                crossAxisSpacing: 15, 
                mainAxisSpacing: 15,
                childAspectRatio: 0.9 // Leggermente più alto per far stare il testo
              ),
              itemCount: widget.room.devices.length,
              itemBuilder: (context, index) => DeviceCard(device: widget.room.devices[index]),
            ),
          ),
        ],
      ),
      // IL TASTO AGGIUNGI DISPOSITIVO (RIPRISTINATO)
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00BFA5),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final res = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => AddDeviceScreen(roomId: widget.room.id))
          );
          // Se torna true, forziamo il refresh della UI
          if (res == true) setState(() {}); 
        },
      ),
    );
  }
}