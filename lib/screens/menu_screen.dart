import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/menu_model.dart';
import '../../widgets/custom_button.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  DateTime _selectedDate = DateTime.now();
  final _lunchController = TextEditingController();
  final _dinnerController = TextEditingController();
  bool _isNonVeg = false;
  bool _isLoading = false;

  String get _formattedDate => DateFormat('yyyy-MM-dd').format(_selectedDate);

  @override
  void dispose() {
    _lunchController.dispose();
    _dinnerController.dispose();
    super.dispose();
  }

  void _loadMenu(MessMenu? menu) {
    if (menu != null) {
      _lunchController.text = menu.lunchMenu;
      _dinnerController.text = menu.dinnerMenu;
      setState(() {
        _isNonVeg = menu.isNonVegDay;
      });
    } else {
      _lunchController.clear();
      _dinnerController.clear();
      setState(() {
        _isNonVeg = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveMenu() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final db = DatabaseService(uid: authService.currentUser!.uid);
      
      await db.saveMenu(
        _formattedDate,
        _lunchController.text.trim(),
        _dinnerController.text.trim(),
        isNonVeg: _isNonVeg,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menu Saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareMenu() async {
    final lunch = _lunchController.text.trim();
    final dinner = _dinnerController.text.trim();

    if (lunch.isEmpty && dinner.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter menu items first')),
      );
      return;
    }

    final String message = 
        '*📅 Menu for ${_formattedDate}*\n\n'
        '*🌞 Lunch:*\n$lunch\n\n'
        '*🌙 Dinner:*\n$dinner\n\n'
        '_Shared via TiffinMate_';

    final Uri launchUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    
    if (!await launchUrl(launchUri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Could not open WhatsApp')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  void _fetchMenu() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final db = DatabaseService(uid: authService.currentUser!.uid);
    final menu = await db.getMenuStream(_formattedDate).first;
    
    if (mounted) {
       _loadMenu(menu);
       setState(() => _isLoading = false);
    }
  }

  @override
  void didUpdateWidget(MenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If date changed via some parent (unlikely here but good practice), refetch
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
               await _selectDate(context);
               _fetchMenu(); // Refetch when date changes
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Menu for $_formattedDate',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _lunchController,
              decoration: const InputDecoration(
                labelText: 'Lunch Menu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wb_sunny),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dinnerController,
              decoration: const InputDecoration(
                labelText: 'Dinner Menu',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.nights_stay),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Is Non-Veg Day? 🍗', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Mark this day as featuring non-veg meals'),
              secondary: Icon(Icons.restaurant, color: _isNonVeg ? Colors.red : Colors.green),
              activeColor: Colors.red,
              value: _isNonVeg,
              onChanged: (v) => setState(() => _isNonVeg = v),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Save Menu',
              onPressed: _saveMenu,
              isLoading: _isLoading,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.share, color: Colors.teal),
              label: const Text('Share to WhatsApp Group', style: TextStyle(color: Colors.teal)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.teal),
              ),
              onPressed: _shareMenu,
            ),
            TextButton(
               onPressed: () {
                 _lunchController.clear();
                 _dinnerController.clear();
                 setState(() => _isNonVeg = false);
               },
               child: const Text('Clear Form'),
            )
          ],
        ),
      ),
    );
  }
}
