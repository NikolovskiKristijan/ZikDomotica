import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddRoomScreen extends StatefulWidget {
  const AddRoomScreen({Key? key}) : super(key: key);

  @override
  State<AddRoomScreen> createState() => _AddRoomScreenState();
}

class _AddRoomScreenState extends State<AddRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _nameController = TextEditingController();

  String _selectedIcon = 'living_room';
  bool _isLoading = false;

  // Nuova Palette Colori da Logo ZK
  final Color _zkBlue = const Color(0xFF0D47A1); // Blu Z
  final Color _zkGreen = const Color(0xFFC6FF00); // Verde Neon K

  final List<Map<String, dynamic>> _roomIcons = [
    {'key': 'living_room', 'label': 'Salotto', 'icon': Icons.chair},
    {'key': 'bedroom', 'label': 'Camera', 'icon': Icons.bed},
    {'key': 'kitchen', 'label': 'Cucina', 'icon': Icons.kitchen},
    {'key': 'bathroom', 'label': 'Bagno', 'icon': Icons.bathtub},
    {'key': 'garage', 'label': 'Garage', 'icon': Icons.garage},
    {'key': 'office', 'label': 'Studio', 'icon': Icons.desktop_mac},
  ];

  Future<void> _saveRoom() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      bool success = await _apiService.addRoom(
        _nameController.text,
        _selectedIcon,
      );

      setState(() => _isLoading = false);

      if (success) {
        if (!mounted) return;
        _showSuccessAnimation();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore durante il salvataggio della stanza'),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icona di successo: Verde Neon K
            Icon(Icons.check_circle_outline, color: _zkGreen, size: 80),
            const SizedBox(height: 20),
            const Text(
              "Stanza Creata!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context);
      Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Nuova Stanza",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _zkGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nome della Stanza",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: "Es. Salotto, Camera di Marco...",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                          // Icona input: Blu Z
                          prefixIcon: Icon(
                            Icons.meeting_room_outlined,
                            color: _zkBlue,
                            size: 20,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 16,
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Inserisci un nome'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      "Scegli un'icona",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: _roomIcons.length,
                      itemBuilder: (context, index) {
                        final iconData = _roomIcons[index];
                        final isSelected = _selectedIcon == iconData['key'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedIcon = iconData['key']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              // Selezionato: Verde Neon K, Non Selezionato: Bianco
                              color: isSelected ? _zkGreen : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                // Selezionato: Verde Neon K, Non Selezionato: Grigio
                                color: isSelected
                                    ? _zkGreen
                                    : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  // Selezionato: Ombra Verde, Non Selezionato: Ombra Grigia
                                  ? [
                                      BoxShadow(
                                        color: _zkGreen.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  iconData['icon'],
                                  // Icona: Bianco su Verde, Blu su Bianco
                                  color: isSelected ? Colors.white : _zkBlue,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  iconData['label'],
                                  style: TextStyle(
                                    // Testo: Bianco su Verde, Grigio su Bianco
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // Pulsante Crea con Gradiente Blu-Verde Neon
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_zkBlue, _zkGreen], // Gradiente Z-K
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: _zkBlue.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors
                                .transparent, // Sfondo trasparente per far vedere il gradiente
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _saveRoom,
                          child: const Text(
                            "CREA STANZA",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
