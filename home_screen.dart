import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:geolocator/geolocator.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'add_room_screen.dart';
import 'room_detail_screen.dart';
import 'log_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<Room> _rooms = [];
  bool _isLoading = true;
  
  late String _timeString;
  late Timer _timer;

  // Nuovi colori ufficiali ZK Domotica
  final Color _zkBlue = const Color(0xFF0D47A1);
  final Color _zkGreen = const Color(0xFFC6FF00);

  @override
  void initState() {
    super.initState();
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) => _updateTime());
    _loadData();
  }

  @override
  void dispose() {
    _timer.cancel(); 
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _timeString = _formatDateTime(DateTime.now());
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getHomeConfig(1);
    setState(() {
      _rooms = data;
      _isLoading = false;
    });
  }

  // Gestione nativa dei permessi hardware ed estrazione coordinate GPS
  Future<void> _getLocationFromGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attiva i servizi di localizzazione (GPS) sul telefono!'))
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permessi di localizzazione GPS rifiutati.'))
        );
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('I permessi GPS sono bloccati permanentemente nelle impostazioni.'))
      );
      return;
    }

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => Center(child: CircularProgressIndicator(color: _zkBlue))
    );
    
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _apiService.sendGpsToServer(position.latitude, position.longitude);
      Navigator.pop(context); 
      _loadData(); 
    } catch (e) {
      Navigator.pop(context);
      print("Errore rilevamento GPS hardware: $e");
    }
  }

  // Finestra di dialogo ibrida per digitare la città o avviare la ricerca GPS
  void _showChangeLocationDialog() {
    final TextEditingController cityController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Imposta Posizione Meteo", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: cityController,
          decoration: const InputDecoration(
            labelText: "Digita una città (es. Milano, Parigi)",
            hintText: "Nome della città...",
            border: OutlineInputBorder()
          ),
          autofocus: true,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.my_location, color: _zkBlue),
            label: Text("Usa GPS", style: TextStyle(color: _zkBlue, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(context); 
              _getLocationFromGPS();  
            },
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Annulla", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _zkBlue),
            onPressed: () async {
              if (cityController.text.isNotEmpty) {
                showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator(color: _zkBlue)));
                await _apiService.updateLocationOnServer(cityController.text);
                Navigator.pop(context); 
                Navigator.pop(context); 
                _loadData(); 
              }
            },
            child: const Text("Cerca", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  IconData _getRoomIcon(String iconName) {
    switch (iconName) {
      case 'living_room': return Icons.chair;
      case 'kitchen': return Icons.kitchen;
      case 'bedroom': return Icons.bed;
      case 'bathroom': return Icons.bathroom;
      default: return Icons.home;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("ZIK Domotica", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _timeString, 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _zkBlue)
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.terminal, color: Colors.black87),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LogScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _zkBlue))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: _zkBlue,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Riquadro Informativo cliccabile per cambiare la localizzazione
                      GestureDetector(
                        onTap: _showChangeLocationDialog,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _zkBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: _zkBlue.withOpacity(0.3))
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Consumo Energetico", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  const SizedBox(height: 5),
                                  Text(_apiService.currentInfoConsumption, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, color: _zkBlue, size: 14),
                                      const SizedBox(width: 3),
                                      Text(_apiService.currentInfoLocation, style: const TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.wb_cloudy, color: Colors.blue, size: 20),
                                      const SizedBox(width: 5),
                                      Text(_apiService.currentInfoTemperature, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Scenari Multipli ad attivazione simultanea (Toggle)
                      const Text("Scenari Rapidi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _apiService.scenes.length,
                          itemBuilder: (context, index) {
                            final s = _apiService.scenes[index];
                            bool isActive = _apiService.currentActiveScenes.contains(s['name']);

                            return GestureDetector(
                              onTap: () async {
                                await _apiService.activateScene(s['name']);
                                _loadData(); 
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 85,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: isActive ? Color(s['color']) : Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: isActive ? Color(s['color']) : Colors.grey.shade300,
                                    width: 2
                                  ),
                                  boxShadow: isActive 
                                      ? [BoxShadow(color: Color(s['color']).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                                      : [const BoxShadow(color: Colors.black12, blurRadius: 4)],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      s['icon'] == 'movie' ? Icons.movie :
                                      s['icon'] == 'bedtime' ? Icons.bedtime :
                                      s['icon'] == 'exit_to_app' ? Icons.exit_to_app : Icons.spa,
                                      color: isActive ? Colors.white : Colors.grey.shade500,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      s['name'], 
                                      style: TextStyle(
                                        color: isActive ? Colors.white : Colors.grey.shade600, 
                                        fontSize: 12, 
                                        fontWeight: FontWeight.bold
                                      )
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Griglia Stuttura Stanze della casa
                      const Text("Le Tue Stanze", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1,
                        ),
                        itemCount: _rooms.length,
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RoomDetailScreen(room: room)),
                              ).then((_) => _loadData());
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(_getRoomIcon(room.icon), color: _zkBlue, size: 30),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 4),
                                      Text("${room.devices.length} dispositivi", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _zkBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddRoomScreen()),
          ).then((value) {
            _loadData();
          });
        },
      ),
    );
  }
}