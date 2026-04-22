import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddDeviceScreen extends StatefulWidget {
  final int roomId;
  const AddDeviceScreen({Key? key, required this.roomId}) : super(key: key);

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _nameController = TextEditingController();
  final _knxController = TextEditingController();
  final ApiService _apiService = ApiService();
  String _selectedType = "light";

  final List<Map<String, dynamic>> _types = [
    {"id": "light", "label": "Luce", "icon": Icons.lightbulb},
    {"id": "shutter", "label": "Serranda", "icon": Icons.blinds},
    {"id": "dimmer", "label": "Dimmer", "icon": Icons.brightness_6},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configura Dispositivo")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Dati Hardware", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00BFA5))),
            const SizedBox(height: 25),
            
            // Campo Nome
            TextField(
              controller: _nameController, 
              decoration: const InputDecoration(
                labelText: "Nome Dispositivo", 
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit)
              )
            ),
            const SizedBox(height: 20),
            
            // Campo KNX + QR Code
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _knxController,
                    decoration: const InputDecoration(
                      labelText: "Indirizzo KNX (es. 1/0/1)", 
                      border: OutlineInputBorder(),
                      hintText: "x/x/x"
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00BFA5), size: 35),
                  tooltip: 'Scansiona codice prodotto',
                  onPressed: () => _showFakeScanner(context),
                )
              ],
            ),
            const SizedBox(height: 35),
            
            const Text("Tipo di attuatore:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            // Selettore Tipologia
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _types.map((t) {
                bool isSel = _selectedType == t['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 95,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF00BFA5) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSel ? const Color(0xFF00BFA5) : Colors.grey.shade300, width: 2),
                      boxShadow: isSel ? [BoxShadow(color: const Color(0xFF00BFA5).withOpacity(0.3), blurRadius: 8)] : [],
                    ),
                    child: Column(
                      children: [
                        Icon(t['icon'], color: isSel ? Colors.white : Colors.grey, size: 30),
                        const SizedBox(height: 8),
                        Text(t['label'], style: TextStyle(color: isSel ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 60),
            
            // Bottone Salva
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00BFA5),
                minimumSize: const Size(double.infinity, 65),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 5
              ),
              onPressed: () async {
                if (_nameController.text.isNotEmpty && _knxController.text.isNotEmpty) {
                  await _apiService.addDevice(
                    widget.roomId, 
                    _nameController.text, 
                    _selectedType, 
                    _knxController.text, 
                    _knxController.text
                  );
                  Navigator.pop(context, true); // Torna indietro con successo
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Compila tutti i campi!")));
                }
              },
              child: const Text("SALVA NEL SISTEMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }

  // Simulatore di Scanner QR
  void _showFakeScanner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_2, size: 200, color: Colors.white24),
            const SizedBox(height: 30),
            const Text("Inquadra il codice QR sul dispositivo", style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 50),
            // Simuliamo una lettura andata a buon fine dopo 2 secondi
            ElevatedButton(
              onPressed: () {
                _knxController.text = "1/1/${DateTime.now().second}";
                Navigator.pop(context);
              }, 
              child: const Text("SIMULA LETTURA OK")
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULLA", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}