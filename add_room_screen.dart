import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({Key? key}) : super(key: key);

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  String _selectedIcon = "living_room";

  final List<Map<String, dynamic>> _icons = [
    {"id": "living_room", "icon": Icons.weekend, "color": Colors.orange},
    {"id": "kitchen", "icon": Icons.kitchen, "color": Colors.green},
    {"id": "bedroom", "icon": Icons.bed, "color": Colors.blue},
    {"id": "bathroom", "icon": Icons.bathtub, "color": Colors.cyan},
    {"id": "garage", "icon": Icons.garage, "color": Colors.grey},
    {"id": "office", "icon": Icons.computer, "color": Colors.indigo},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crea Stanza")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _controller, decoration: const InputDecoration(labelText: "Nome Stanza", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            const Text("Seleziona Icona:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15),
              itemCount: _icons.length,
              itemBuilder: (context, i) {
                final item = _icons[i];
                final isSel = _selectedIcon == item['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = item['id']),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSel ? item['color'] : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSel ? item['color'] : Colors.grey.shade300, width: 2),
                    ),
                    child: Icon(item['icon'], color: isSel ? Colors.white : item['color'], size: 35),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF007F), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: () async {
                if (_controller.text.isNotEmpty) {
                  await _apiService.addRoom(_controller.text, _selectedIcon);
                  Navigator.pop(context, true);
                }
              },
              child: const Text("SALVA STANZA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}