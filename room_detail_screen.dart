import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'add_device_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  final Room room;

  const RoomDetailScreen({Key? key, required this.room}) : super(key: key);

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final ApiService _apiService = ApiService();
  late List<Device> _devices;
  bool _isLoading = false;

  // Nuovo colore ufficiale ZK Domotica
  final Color _zkBlue = const Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();
    _devices = widget.room.devices;
  }

  // Ricarica i dati per vedere subito il nuovo dispositivo inserito
  Future<void> _refreshDevices() async {
    setState(() => _isLoading = true);
    List<Room> updatedRooms = await _apiService.getHomeConfig(1);
    var currentRoom = updatedRooms.firstWhere(
      (r) => r.id == widget.room.id,
      orElse: () => widget.room,
    );
    setState(() {
      _devices = currentRoom.devices;
      _isLoading = false;
    });
  }

  IconData _getDeviceIcon(String type) {
    switch (type) {
      case 'light':
        return Icons.lightbulb_outline;
      case 'shutter':
        return Icons.blur_linear;
      case 'plug':
        return Icons.power;
      default:
        return Icons.device_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("${_devices.length} dispositivi configurati", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _zkBlue))
          : _devices.isEmpty
              ? const Center(
                  child: Text(
                    "Nessun dispositivo.\nTocca il tasto + per aggiungerlo.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  // Creiamo una griglia a 2 colonne di elementi quadrati
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,         // 2 quadrati per riga
                    crossAxisSpacing: 14,      // Spazio orizzontale
                    mainAxisSpacing: 14,       // Spazio verticale
                    childAspectRatio: 1.0,     // Rapporto 1:1 lo rende perfettamente quadrato
                  ),
                  itemCount: _devices.length,
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    bool isOn = device.status == 1;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          device.status = isOn ? 0 : 1;
                        });
                        // Invia il comando KNX al server
                        _apiService.sendCommand(device.name, device.knxWrite, device.status);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // Se è acceso diventa del colore blu aziendale, se è spento rimane bianco pulito
                          color: isOn ? _zkBlue : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: isOn 
                                  ? _zkBlue.withOpacity(0.3) 
                                  : Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Riga superiore: Icona e indicatore di stato a cerchio
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isOn ? Colors.white.withOpacity(0.2) : _zkBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getDeviceIcon(device.type), 
                                    color: isOn ? Colors.white : _zkBlue,
                                    size: 24,
                                  ),
                                ),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isOn ? Colors.white : Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            
                            // Scritte inferiori: Nome e dettagli tecnici KNX
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isOn ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "KNX: ${device.knxWrite}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOn ? Colors.white70 : Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
      floatingActionButton: FloatingActionButton(
        backgroundColor: _zkBlue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final bool? needRefresh = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddDeviceScreen(
                roomId: widget.room.id,
                roomName: widget.room.name,
              ),
            ),
          );

          if (needRefresh == true) {
            _refreshDevices();
          }
        },
      ),
    );
  }
}