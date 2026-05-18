import 'package:flutter/material.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({Key? key}) : super(key: key);

  // Qui definiamo la variabile systemLogs che causava l'errore!
  // Per ora usiamo dei log finti per testare l'interfaccia.
  final List<String> systemLogs = const [
    "[SISTEMA] Avvio applicazione completato.",
    "[RETE] Connessione al server backend (Node.js) stabilita.",
    "[METEO] Sincronizzazione dati atmosferici completata.",
    "[KNX] Inizializzazione stanze e dispositivi completata.",
    "[UTENTE] Accesso effettuato con successo."
  ];

  // Colore ufficiale aziendale ZK Domotica
  final Color _zkBlue = const Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Log di Sistema", 
          style: TextStyle(
            color: Colors.black87, 
            fontWeight: FontWeight.bold, 
            fontSize: 18
          )
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: _zkBlue.withOpacity(0.15)),
          ),
          child: systemLogs.isEmpty
              ? const Center(
                  child: Text(
                    "Nessun log disponibile.",
                    style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                  ),
                )
              : ListView.builder(
                  itemCount: systemLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Il prompt del terminale ">" in blu ZK deciso
                          Text(
                            "> ",
                            style: TextStyle(
                              color: _zkBlue,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                          ),
                          // Testo del log scurito a nero antracite per massima leggibilità
                          Expanded(
                            child: Text(
                              systemLogs[index],
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500, // Leggermente più spesso per risaltare
                                fontFamily: 'monospace',
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}