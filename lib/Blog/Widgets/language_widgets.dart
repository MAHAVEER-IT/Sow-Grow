import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utility/language_constants.dart';
import '../../utils/Language/app_localizations.dart';
import '../../utils/Language/language_provider.dart';

/// Reusable language selection dialog for blog pages
class LanguageSelectionDialog extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageSelected;

  const LanguageSelectionDialog({
    super.key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return AlertDialog(
      title: Text(
        AppLocalizations.translate(
          'selectLanguage',
          languageProvider.currentLanguage,
        ),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green.shade600,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Container(
        width: double.minPositive,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: BlogLanguageConstants.availableLanguages.map((language) {
            return ListTile(
              title: Text(
                language['name']!,
                style: TextStyle(
                  fontWeight: currentLanguage == language['code']
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              leading: Radio<String>(
                value: language['code']!,
                groupValue: currentLanguage,
                activeColor: Colors.green.shade600,
                onChanged: (String? value) {
                  Navigator.pop(context);
                  if (value != null && value != currentLanguage) {
                    onLanguageSelected(value);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            AppLocalizations.translate(
              'cancel',
              languageProvider.currentLanguage,
            ),
            style: TextStyle(color: Colors.green.shade600),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  /// Show the language selection dialog
  static void show(
    BuildContext context, {
    required String currentLanguage,
    required Function(String) onLanguageSelected,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return LanguageSelectionDialog(
          currentLanguage: currentLanguage,
          onLanguageSelected: onLanguageSelected,
        );
      },
    );
  }
}

/// Loading indicator for translation process
class TranslationLoadingWidget extends StatelessWidget {
  final String message;

  const TranslationLoadingWidget({
    super.key,
    this.message = 'Translating content...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade800),
          ),
          SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
