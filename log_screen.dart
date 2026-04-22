import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Sfondo da terminale vero
      appBar: AppBar(
        title: const Text("Console KNX", style: TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 18)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.greenAccent),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Connessione TCP/IP a Gateway KNX stabilita.\nIn ascolto per eventi bus...\n", 
              style: TextStyle(color: Colors.grey, fontFamily: 'monospace', fontSize: 12)
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ApiService.systemLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      "> ${ApiService.systemLogs[index]}",
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 13),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}