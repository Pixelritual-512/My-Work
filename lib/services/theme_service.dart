import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ThemeService extends ChangeNotifier {
  final String _themeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  String? _uid;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeService() {
    _loadLocalTheme();
  }

  void updateUser(String? uid) {
    _uid = uid;
    if (_uid != null) {
      _fetchCloudTheme();
    }
  }

  Future<void> _loadLocalTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final String? themeStr = prefs.getString(_themeKey);
    if (themeStr != null) {
       _setModeFromString(themeStr, notify: true);
    }
  }

  Future<void> _fetchCloudTheme() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('owners').doc(_uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('themePreference')) {
          final pref = data['themePreference'];
          // Cloud always wins. Update local cache to match.
          _setModeFromString(pref, notify: true);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_themeKey, pref);
        }
      }
    } catch (e) {
      print('Error fetching cloud theme: $e');
    }
  }

  void _setModeFromString(String themeStr, {bool notify = false}) {
    ThemeMode newMode = ThemeMode.system;
    if (themeStr == 'light') newMode = ThemeMode.light;
    if (themeStr == 'dark') newMode = ThemeMode.dark;
    
    if (_themeMode != newMode) {
      _themeMode = newMode;
      if (notify) notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';

    // 1. Save Locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, modeStr);

    // 2. Save to Cloud if logged in
    if (_uid != null) {
      try {
        await FirebaseFirestore.instance.collection('owners').doc(_uid).set({
          'themePreference': modeStr
        }, SetOptions(merge: true));
      } catch (e) {
        print('Error saving cloud theme: $e');
      }
    }
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setThemeMode(ThemeMode.dark);
    } else {
      await setThemeMode(ThemeMode.light);
    }
  }
}
