import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../widgets/room_card.dart';
import 'room_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Room>> _roomsFuture;

  @override
  void initState() {
    super.initState();
    //_loadData();
    _roomsFuture = _getFakeRooms();
  }

  //void _loadData() {
  // 1 è l'ID utente fittizio. In futuro lo prenderai dal login.
  //_roomsFuture = _apiService.getHomeConfig(1);
  //}
  // Metti questo dentro HomeScreen per testare se non hai il backend pronto
  Future<List<Room>> _getFakeRooms() async {
    await Future.delayed(const Duration(seconds: 1)); // Finto ritardo rete
    return [
      Room(
        id: 1,
        name: "Salotto",
        icon: "living_room",
        devices: [
          Device(id: 1, name: "Luce", type: "light", knxWrite: "", knxRead: ""),
          Device(
            id: 2,
            name: "Tapparella",
            type: "shutter",
            knxWrite: "",
            knxRead: "",
          ),
        ],
      ),
      Room(id: 2, name: "Cucina", icon: "kitchen", devices: []),
    ];
  }
  // Poi nell'initState usa: _roomsFuture = _getFakeRooms();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Bentornato, Matteo",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "La tua casa è online",
              style: TextStyle(fontSize: 14, color: Colors.amber),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.amber,
        child: const Icon(Icons.add_home, color: Colors.black),
        onPressed: () {
          // Qui aprirai il form per creare una nuova stanza
        },
      ),
      body: FutureBuilder<List<Room>>(
        future: _roomsFuture,
        builder: (context, snapshot) {
          // 1. CARICAMENTO
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          // 2. ERRORE
          if (snapshot.hasError) {
            // Se il server è spento, mostriamo un messaggio gentile
            return Center(
              child: Text(
                "Errore connessione: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 3. DATI PRONTI
          final rooms = snapshot.data ?? [];

          if (rooms.isEmpty) {
            return const Center(
              child: Text(
                "Nessuna stanza. Creane una col tasto +",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          // 4. LISTA STANZE
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: rooms.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 16),
            itemBuilder: (ctx, index) {
              return SizedBox(
                height: 120, // Altezza fissa per le card delle stanze
                child: RoomCard(
                  room: rooms[index],
                  onTap: () {
                    // NAVIGAZIONE: Vai al dettaglio stanza
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RoomDetailScreen(room: rooms[index]),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
