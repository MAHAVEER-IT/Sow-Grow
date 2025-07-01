import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sow_and_grow/utils/Language/app_localizations.dart';
import 'package:sow_and_grow/utils/Language/language_provider.dart';

class LanguageSettings extends StatefulWidget {
  const LanguageSettings({Key? key}) : super(key: key);

  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {
  // Green color palette
  final Color primaryGreen = const Color(0xFF2E7D32); // Dark green
  final Color secondaryGreen = const Color(0xFF4CAF50); // Medium green
  final Color lightGreen = const Color(0xFFA5D6A7); // Light green
  final Color accentGreen = const Color(0xFF00C853); // Accent green
  final Color backgroundGreen = const Color(
    0xFFE8F5E9,
  ); // Very light green background

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: backgroundGreen,
      appBar: AppBar(
        title: Text(
          AppLocalizations.translate(
            'selectLanguage',
            languageProvider.currentLanguage,
          ),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundGreen, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: lightGreen.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, color: primaryGreen, size: 28),
                    const SizedBox(width: 15),
                    Text(
                      AppLocalizations.translate(
                        'selectLanguage',
                        languageProvider.currentLanguage,
                      ),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _buildLanguageOption('English', 'English', Icons.flag_outlined),
              _buildLanguageOption('தமிழ்', 'Tamil', Icons.flag_outlined),
              _buildLanguageOption('हिंदी', 'Hindi', Icons.flag_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String displayName, String value, IconData icon) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isSelected = languageProvider.currentLanguage == value;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accentGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Card(
        elevation: isSelected ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: isSelected ? accentGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            languageProvider.setLanguage(value);
            _showLanguageChangedSnackBar(displayName, value);
          },
          splashColor: lightGreen,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: RadioListTile<String>(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? lightGreen
                          : lightGreen.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? primaryGreen : secondaryGreen,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? primaryGreen : Colors.black87,
                    ),
                  ),
                ],
              ),
              value: value,
              groupValue: languageProvider.currentLanguage,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  languageProvider.setLanguage(newValue);
                  _showLanguageChangedSnackBar(displayName, newValue);
                }
              },
              activeColor: accentGreen,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              controlAffinity: ListTileControlAffinity.trailing,
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageChangedSnackBar(String displayName, String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              '${AppLocalizations.translate('languageChanged', value)} $displayName',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        backgroundColor: accentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}
