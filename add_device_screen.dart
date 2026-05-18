import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AddDeviceScreen extends StatefulWidget {
  final int roomId;
  final String roomName;

  const AddDeviceScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _knxWriteController = TextEditingController();
  final TextEditingController _knxReadController = TextEditingController();

  String _selectedType = 'light';
  bool _isLoading = false;

  // Nuova Palette Colori da Logo ZK
  final Color _zkBlue = const Color(0xFF0D47A1); // Blu Z
  final Color _zkGreen = const Color(0xFFC6FF00); // Verde Neon K

  final List<Map<String, dynamic>> _deviceTypesConfig = [
    {'key': 'light', 'label': 'Luce', 'icon': Icons.lightbulb_outline},
    {'key': 'shutter', 'label': 'Tapparella', 'icon': Icons.blur_linear},
    {'key': 'plug', 'label': 'Presa/Carico', 'icon': Icons.power},
  ];

  Future<void> _saveDevice() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      bool success = await _apiService.addDevice(
        widget.roomId,
        _nameController.text,
        _selectedType,
        _knxWriteController.text,
        _knxReadController.text,
      );

      setState(() => _isLoading = false);

      if (success) {
        if (!mounted) return;
        _showSuccessAnimation();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore durante il salvataggio'),
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
              "Dispositivo Aggiunto!",
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
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
            controller: controller,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              // Icona input: Blu Z
              prefixIcon: Icon(icon, color: _zkBlue, size: 20),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                // Bordo focus: Verde Neon K
                borderSide: BorderSide(color: _zkGreen, width: 1.5),
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Nuovo Dispositivo",
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "Aggiungi a ${widget.roomName}",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
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
                    _buildTextField(
                      controller: _nameController,
                      label: "Nome del Dispositivo",
                      hint: "Es. Luce Specchio, Presa TV, Tapparella Est...",
                      icon: Icons.label_outline,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Inserisci un nome'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    const Text(
                      "Tipo di Dispositivo",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _deviceTypesConfig.map((type) {
                        bool isSelected = _selectedType == type['key'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedType = type['key']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                // Selezionato: Verde Neon K, Non Selezionato: Bianco
                                color: isSelected ? _zkGreen : Colors.white,
                                borderRadius: BorderRadius.circular(12),
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
                                children: [
                                  Icon(
                                    type['icon'],
                                    // Icona: Bianco su Verde, Blu su Bianco
                                    color: isSelected ? Colors.white : _zkBlue,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    type['label'],
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
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              // Icona: Grigio scuro / Blu profondo
                              Icon(
                                Icons.router_outlined,
                                color: Colors.blueGrey,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Configurazione KNX",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _knxWriteController,
                            label: "Indirizzo Scrittura (Comando)",
                            hint: "Es. 1/1/1",
                            icon: Icons.unfold_more_outlined,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Necessario'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _knxReadController,
                            label: "Indirizzo Lettura (Stato)",
                            hint: "Es. 1/1/101",
                            icon: Icons.visibility_outlined,
                            validator: (value) => value == null || value.isEmpty
                                ? 'Necessario'
                                : null,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Pulsante Salva con Gradiente Blu-Verde Neon
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
                              color: _zkBlue.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
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
                          onPressed: _saveDevice,
                          child: const Text(
                            "SALVA DISPOSITIVO",
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
