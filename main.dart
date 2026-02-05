import 'package:flutter/material.dart';
// IMPORTANTE: Qui importiamo la schermata Home che sta nell'altra cartella
import 'screens/home_screen.dart'; 

void main() {
  // Questo è il punto di partenza di tutta l'app
  runApp(const DomoticaApp());
}

class DomoticaApp extends StatelessWidget {
  const DomoticaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Titolo che appare nel task manager del telefono
      title: 'Smart Home KNX',
      
      // Togliamo la scritta "DEBUG" in alto a destra
      debugShowCheckedModeBanner: false,

      // --- CONFIGURAZIONE DEL TEMA (DESIGN) ---
      // Qui definiamo i colori per tutta l'app in un colpo solo.
      theme: ThemeData(
        // Impostiamo il tema scuro (Dark Mode) come default
        brightness: Brightness.dark,
        
        // Colore di sfondo generale (Grigio Scuro stile Apple)
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        
        // Colore primario (Giallo Ambra per i dettagli attivi)
        primaryColor: Colors.amber,
        
        // Stile della barra in alto (AppBar)
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // Trasparente
          elevation: 0, // Niente ombreggiatura
          centerTitle: false, // Titolo allineato a sinistra
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white), // Colore icone in alto
        ),
        
        // Colore del pulsante flottante (+)
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black, // Icona nera su sfondo giallo
        ),
      ),

      // --- PAGINA INIZIALE ---
      // Diciamo all'app: "Appena parti, mostra la HomeScreen"
      home: const HomeScreen(),
    );
  }
}