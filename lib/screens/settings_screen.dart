import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/owner_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isDataLoaded = false;
  late TextEditingController _messNameController;
  late TextEditingController _oneTimeFeeController;
  late TextEditingController _twoTimeFeeController;
  late TextEditingController _rulesController;
  late TextEditingController _whatsappLinkController;
  late TextEditingController _upiIdController;
  late TextEditingController _guestVegController;
  late TextEditingController _guestNonVegController;

  @override
  void initState() {
    super.initState();
    _messNameController = TextEditingController();
    _oneTimeFeeController = TextEditingController();
    _twoTimeFeeController = TextEditingController();
    _rulesController = TextEditingController();
    _whatsappLinkController = TextEditingController();
    _upiIdController = TextEditingController();
    _guestVegController = TextEditingController();
    _guestNonVegController = TextEditingController();
  }

  @override
  void dispose() {
    _messNameController.dispose();
    _oneTimeFeeController.dispose();
    _twoTimeFeeController.dispose();
    _rulesController.dispose();
    _whatsappLinkController.dispose();
    _upiIdController.dispose();
    _guestVegController.dispose();
    _guestNonVegController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final db = DatabaseService(uid: authService.currentUser!.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: StreamBuilder<Owner?>(
        stream: db.ownerStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final owner = snapshot.data!;
          if (!_isDataLoaded) {
            _messNameController.text = owner.messName;
            _oneTimeFeeController.text = owner.oneTimeFee.toString();
            _twoTimeFeeController.text = owner.twoTimeFee.toString();
            _rulesController.text = owner.rules;
            _whatsappLinkController.text = owner.whatsappGroupLink;
            _upiIdController.text = owner.upiId;
            _guestVegController.text = owner.guestVegPrice.toString();
            _guestNonVegController.text = owner.guestNonVegPrice.toString();
            _isDataLoaded = true;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSectionTitle('Mess Details'),
                _buildTextField(_messNameController, 'Mess Name', Icons.restaurant),
                _buildTextField(_rulesController, 'Rules/Instructions', Icons.list, maxLines: 3),
                
                const SizedBox(height: 20),
                _buildSectionTitle('Pricing (Monthly)'),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_oneTimeFeeController, '1-Time Fee', Icons.attach_money, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_twoTimeFeeController, '2-Time Fee', Icons.attach_money, isNumber: true)),
                  ],
                ),

                const SizedBox(height: 20),
                _buildSectionTitle('Guest Pricing'),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_guestVegController, 'Veg Plate', Icons.eco, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(_guestNonVegController, 'Non-Veg Plate', Icons.kebab_dining, isNumber: true)),
                  ],
                ),

                const SizedBox(height: 20),
                _buildSectionTitle('Integrations'),
                _buildTextField(_upiIdController, 'UPI ID (for payments)', Icons.payment, hint: 'example@okicici'),
                _buildTextField(_whatsappLinkController, 'WhatsApp Group Link', Icons.chat, hint: 'https://chat.whatsapp.com/...'),

                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Sanitize and Parse
                      double? parsePrice(String text) {
                        if (text.trim().isEmpty) return null;
                        String clean = text.replaceAll(',', '').replaceAll(' ', '');
                        return double.tryParse(clean);
                      }

                      final oneTime = parsePrice(_oneTimeFeeController.text);
                      final twoTime = parsePrice(_twoTimeFeeController.text);
                      final vegPrice = parsePrice(_guestVegController.text);
                      final nonVegPrice = parsePrice(_guestNonVegController.text);

                      await db.updateOwnerSettings(
                        messName: _messNameController.text,
                        monthlyFeeOneTime: oneTime,
                        monthlyFeeTwoTime: twoTime,
                        rules: _rulesController.text,
                        whatsappGroupLink: _whatsappLinkController.text,
                        upiId: _upiIdController.text,
                        guestVegPrice: vegPrice,
                        guestNonVegPrice: nonVegPrice,
                      );
                      
                      String msg = 'Settings saved!';
                      if (oneTime != null) msg += '\n1-Time Fee: ₹${oneTime.toInt()}';
                      
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                      ));
                    }
                  },
                  child: const Text('Save Settings'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF6C63FF))),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        maxLines: maxLines,
      ),
    );
  }
}
