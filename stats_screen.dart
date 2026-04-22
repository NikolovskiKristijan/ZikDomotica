import 'package:flutter/material.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analisi Energetica")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Consumo Settimanale", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            // Finto Grafico a Barre
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar("Lun", 40), _bar("Mar", 70), _bar("Mer", 90),
                _bar("Gio", 50), _bar("Ven", 110), _bar("Sab", 130), _bar("Dom", 80),
              ],
            ),
            const SizedBox(height: 40),
            _statTile("Dispositivo più energivoro", "Forno Cucina", Icons.kitchen, Colors.orange),
            _statTile("Risparmio rispetto a ieri", "+12%", Icons.trending_down, Colors.green),
            _statTile("Stato Pannelli Solari", "Produzione OK", Icons.wb_sunny, Colors.yellow.shade700),
          ],
        ),
      ),
    );
  }

  Widget _bar(String day, double height) {
    return Column(
      children: [
        Container(
          height: height, width: 30,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00E676)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 5),
        Text(day, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _statTile(String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}