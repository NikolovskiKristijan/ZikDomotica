import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/app_models.dart';
import '../widgets/room_card.dart';
import 'add_room_screen.dart';
import 'room_detail_screen.dart';
import 'stats_screen.dart'; // Assicurati di aver creato questo file
import 'log_screen.dart';   // Assicurati di aver creato questo file

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
    _roomsFuture = _apiService.getHomeConfig(1);
  }

  // Funzione per ricaricare i dati quando si torna dalle altre pagine
  void _refreshData() {
    setState(() {
      _roomsFuture = _apiService.getHomeConfig(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // HEADER PROFESSIONALE CON METEO E AZIONI
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF00BFA5),
            actions: [
              IconButton(
                icon: const Icon(Icons.bar_chart, color: Colors.white),
                tooltip: 'Statistiche Energia',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatsScreen())),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none, color: Colors.white),
                    onPressed: () => _showNotifications(context),
                  ),
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                    ),
                  )
                ],
              ),
              IconButton(
                icon: const Icon(Icons.terminal, color: Colors.white),
                tooltip: 'Console KNX',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LogScreen())),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.only(top: 80, left: 25, right: 25),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00BFA5), Color(0xFF00E676)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Bentornato, Casa", style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoTile(Icons.bolt, "2.4 kW", "Consumo"),
                        _infoTile(Icons.thermostat, "21°C", "Esterna"),
                        _infoTile(Icons.cloud, "Sereno", "Meteo"),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // SEZIONE SCENARI RAPIDI
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 25, 20, 15),
                  child: Text("Scenari Rapidi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: _apiService.scenes.length,
                    itemBuilder: (context, i) {
                      final s = _apiService.scenes[i];
                      return Container(
                        width: 90,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: Color(s['color']).withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Color(s['color']).withOpacity(0.3))
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_getSceneIcon(s['icon']), color: Color(s['color'])),
                            const SizedBox(height: 5),
                            Text(s['name'], style: TextStyle(color: Color(s['color']), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 20, top: 35, bottom: 10),
                  child: Text("Le tue Stanze", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                ),
              ],
            ),
          ),

          // LISTA STANZE DINAMICA
          FutureBuilder<List<Room>>(
            future: _roomsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Text("Nessuna stanza configurata")));
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => RoomCard(
                    room: snapshot.data![index],
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (context) => RoomDetailScreen(room: snapshot.data![index])));
                      _refreshData();
                    },
                  ),
                  childCount: snapshot.data!.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 110)), // Spazio per i bottoni flottanti
        ],
      ),

      // BOTTONI FLOTTANTI (AGGIUNGI E VOCE)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton.extended(
            heroTag: "btn_add",
            backgroundColor: const Color(0xFFFF007F),
            label: const Text("Nuova Stanza", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddRoomScreen()));
              if (res == true) _refreshData();
            },
          ),
          FloatingActionButton(
            heroTag: "btn_mic",
            backgroundColor: Colors.white,
            elevation: 4,
            child: const Icon(Icons.mic, color: Color(0xFF00BFA5), size: 30),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🎙️ In ascolto... Prova a dire 'Accendi luci'"), 
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF2D3436),
                )
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget Helper per le info meteo/consumi
  Widget _infoTile(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  // Mostra il centro notifiche
  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Centro Notifiche", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _notifItem("Sicurezza", "Allarme perimetrale attivato (08:30)", Icons.security, Colors.blue),
            _notifItem("Manutenzione", "Filtro aria VMC da sostituire", Icons.build, Colors.orange),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _notifItem(String title, String desc, IconData icon, Color col) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: col.withOpacity(0.1), child: Icon(icon, color: col, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
    );
  }

  IconData _getSceneIcon(String name) {
    if (name == 'movie') return Icons.movie;
    if (name == 'bedtime') return Icons.bedtime;
    if (name == 'exit_to_app') return Icons.exit_to_app;
    return Icons.spa;
  }
}