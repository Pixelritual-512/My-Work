import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/theme_service.dart';
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
                _buildTextField(
                  _rulesController, 
                  'Rules/Instructions', 
                  Icons.list, 
                  maxLines: null, // Allow unlimited lines
                  hint: 'Enter each rule on a new line (one below the other)',
                ),
                
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
                        messName: _messNameController.text.trim(),
                        monthlyFeeOneTime: oneTime,
                        monthlyFeeTwoTime: twoTime,
                        rules: _rulesController.text.trim(),
                        whatsappGroupLink: _whatsappLinkController.text.trim(),
                        upiId: owner.upiId,
                        guestVegPrice: vegPrice,
                        guestNonVegPrice: nonVegPrice,
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Settings saved!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ));
                    }
                  },
                  child: const Text('Save Settings'),
                ),
                
                const SizedBox(height: 20),
                _buildSectionTitle('Appearance'),
                Consumer<ThemeService>(
                  builder: (context, themeService, _) {
                    String getModeLabel(ThemeMode mode) {
                      switch (mode) {
                        case ThemeMode.light: return 'Light';
                        case ThemeMode.dark: return 'Dark';
                        case ThemeMode.system: return 'System';
                      }
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: const Text(
                            'Appearance', 
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  getModeLabel(themeService.themeMode),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.keyboard_arrow_down, color: Theme.of(context).iconTheme.color),
                            ],
                          ),
                          children: [
                            const Divider(height: 1),
                            _buildThemeOption(context, themeService, ThemeMode.light, 'Light theme', 
                              Icon(Icons.light_mode, size: 20, color: Theme.of(context).iconTheme.color)),
                            const Divider(height: 1),
                            _buildThemeOption(context, themeService, ThemeMode.dark, 'Dark theme', 
                              Icon(Icons.dark_mode, size: 20, color: Theme.of(context).iconTheme.color)),
                            const Divider(height: 1),
                            _buildThemeOption(
                              context, 
                              themeService, 
                              ThemeMode.system, 
                              'System default', 
                              SizedBox(
                                width: 20, 
                                height: 20,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.black87, // Black circle
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.black87, width: 1.5) // White with black outline
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                
                const SizedBox(height: 30),
                const Divider(),
                const SizedBox(height: 10),
                
                // Account Actions Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Logout Button (Small)
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && mounted) {
                          await authService.signOut();
                          if (mounted) {
                            Navigator.of(context).pushReplacementNamed('/login');
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text('Logout'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange,
                      ),
                    ),
                    
                    // Delete Account Button
                    TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
                            content: const Text(
                              '⚠️ WARNING: This will permanently delete:\n\n'
                              '• Your account\n'
                              '• All student records\n'
                              '• All attendance data\n'
                              '• All payment records\n'
                              '• All menu data\n\n'
                              'This action CANNOT be undone!',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text('Delete Everything'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && mounted) {
                          // Second confirmation with typed verification
                          final verified = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) {
                              final controller = TextEditingController();
                              return AlertDialog(
                                title: const Text('Final Confirmation'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Type DELETE to confirm:'),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        hintText: 'Type DELETE',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (controller.text.trim() == 'DELETE') {
                                        Navigator.pop(ctx, true);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Please type DELETE exactly')),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Confirm Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (verified == true && mounted) {
                            try {
                              // Delete all data
                              await db.deleteAllOwnerData();
                              // Delete auth account
                              await authService.deleteAccount();
                              
                              if (mounted) {
                                Navigator.of(context).pushReplacementNamed('/login');
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: const Text('Delete Account'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int? maxLines = 1, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
        ),
        keyboardType: isNumber 
            ? TextInputType.number 
            : (maxLines == null || maxLines > 1) ? TextInputType.multiline : TextInputType.text,
        maxLines: maxLines,
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, ThemeService service, ThemeMode mode, String label, Widget icon) {
    final isSelected = service.themeMode == mode;
    return InkWell(
      onTap: () => service.setThemeMode(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyLarge?.color
            ))),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 24)
            else
              const Icon(Icons.circle_outlined, color: Colors.grey, size: 24),
          ],
        ),
      ),
    );
  }
}
