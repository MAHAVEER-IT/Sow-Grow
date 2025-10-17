import 'package:flutter/material.dart';

/// Authentication related constants
class AuthConstants {
  // Color scheme
  static final Color primaryGreen = Colors.green.shade400;
  static final Color primaryGreenDark = Colors.green.shade600;
  static final Color primaryGreenLight = Colors.green.shade700;
  static final Color textGreen = Colors.green.shade800;

  // Background gradient colors
  static final List<Color> backgroundGradient = [
    Colors.green.shade50,
    Colors.green.shade100,
    Colors.white,
  ];

  // Text styles
  static final TextStyle headerTextStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.green.shade600,
  );

  static final TextStyle titleTextStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 1.2,
    shadows: [
      Shadow(
        blurRadius: 10.0,
        color: Colors.green.shade200,
        offset: Offset(2, 2),
      ),
    ],
  );

  static final TextStyle subtitleTextStyle = TextStyle(
    fontSize: 16,
    color: Colors.white,
    fontWeight: FontWeight.w500,
  );

  static final TextStyle logoTextStyle = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Colors.green.shade800,
    letterSpacing: 1.5,
    shadows: [
      Shadow(
        blurRadius: 10.0,
        color: Colors.green.shade200,
        offset: Offset(2, 2),
      ),
    ],
  );

  // Button style
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.green.shade400,
    foregroundColor: Colors.white,
    elevation: 5,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    padding: EdgeInsets.symmetric(vertical: 12),
  );

  // Validation regex
  static final RegExp emailRegExp = RegExp(
    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
  );

  // Common decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 5)),
    ],
  );

  // Common constants
  static const double borderRadius = 15.0;
  static const double cardPadding = 20.0;
}
