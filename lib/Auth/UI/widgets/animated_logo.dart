import 'package:flutter/material.dart';

/// Reusable animated logo widget for authentication pages
class AnimatedLogo extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final TextStyle titleStyle;

  const AnimatedLogo({
    Key? key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.titleStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 60, color: iconColor),
        SizedBox(height: 10),
        Text(title, style: titleStyle),
      ],
    );
  }
}
