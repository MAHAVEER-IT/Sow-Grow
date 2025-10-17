import 'package:flutter/material.dart';

/// Reusable custom text field widget for authentication forms
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final String? errorText;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;

  const AuthTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.icon,
    this.errorText,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey.shade50,
        border: Border.all(
          color: errorText != null ? Colors.red : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          errorText: errorText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
    );
  }
}
