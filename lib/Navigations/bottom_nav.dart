import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sow_and_grow/utils/Language/app_localizations.dart';
import 'package:sow_and_grow/utils/Language/language_provider.dart';

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  const BottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onTabChange,
  }) : super(key: key);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.article,
            label: _getTranslation('AgriTalks', currentLanguage),
            index: 0,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.chat_bubble_outline,
            label: _getTranslation('FarmHelper', currentLanguage),
            index: 1,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.vaccines,
            label: _getTranslation('Livestocare', currentLanguage),
            index: 2,
          ),
        ],
      ),
    );
  }

  String _getTranslation(String key, String language) {
    try {
      return AppLocalizations.translate(key, language);
    } catch (e) {
      const fallbackValues = {
        'blog': 'Blog',
        'chatbot': 'Chat',
        'profile': 'Profile',
      };
      return fallbackValues[key] ?? key;
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = widget.selectedIndex == index;
    return InkWell(
      onTap: () => widget.onTabChange(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isSelected ? Colors.green.shade700 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green.shade900 : Colors.grey.shade700,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.green.shade900
                    : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
