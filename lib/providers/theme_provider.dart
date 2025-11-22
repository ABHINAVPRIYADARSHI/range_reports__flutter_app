import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  List<Color> get gradientColors => isDarkMode
      ? [
          const Color(0xFF0F2027), // Dark teal
          const Color(0xFF203A43), // Darker teal
          const Color(0xFF2C5364), // Dark blue-gray
        ]
      : [
          const Color(0xFFE0EAFC), // Very light blue
          const Color(0xFFCFDEF3), // Light blue
          const Color(0xFFE0EAFC), // Very light blue
        ];

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  void setLight() {
    _themeMode = ThemeMode.light;
    notifyListeners();
  }

  void setDark() {
    _themeMode = ThemeMode.dark;
    notifyListeners();
  }
}
