import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sow_and_grow/Auth/UI/loginPage.dart';
import 'package:sow_and_grow/Blog/Create_Blog/UI/create_blog_ui.dart'; // Add this import
import 'package:sow_and_grow/Settings/UI/language_settings.dart';
import 'package:sow_and_grow/utils/Language/app_localizations.dart';

import '../Blog/UI/Blog_UI.dart';
import '../Chat/UI/oneTOone/doctors_page.dart';
import '../Help/UI/Help_page.dart';
import '../Map_diseise/UI/Dedict_desisease.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  String _currentLanguage = 'English';
  String? _username;
  String? _email;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLanguage = prefs.getString('language') ?? 'English';
      _username = prefs.getString('username') ?? 'Guest';
      _email = prefs.getString('email') ?? 'guest@example.com';
      _userRole = prefs.getString('userType') ?? 'user';
      print('User Type: $_userRole'); // Debug log
    });
  }

  Future<void> _handleLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('userId');
      await prefs.remove('username');
      await prefs.remove('email');
      await prefs.remove('userType');

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTranslatedText('logoutSuccess')),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getTranslatedText(String key) {
    return AppLocalizations.translate(key, _currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    print('Building drawer with user type: $_userRole'); // Debug log
    return Drawer(
      backgroundColor: Colors.green.shade50,
      surfaceTintColor: Colors.green.shade100,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _username ?? 'Guest',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              _email ?? 'guest@example.com',
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
            currentAccountPicture: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.network(
                  'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_username ?? "Guest")}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person),
                ),
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade500, Colors.green.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              image: const DecorationImage(
                image: AssetImage('images/drawer.png'),
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  Icons.home,
                  _getTranslatedText('home'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => Blog()),
                  ),
                ),
                _buildDrawerItem(
                  Icons.create_outlined,
                  _getTranslatedText('Share AgriTalks'),
                  onTap: () => _navigateToCreateBlog(context),
                ),
                _buildDrawerItem(
                  _userRole == 'doctor' ? Icons.chat : Icons.person_pin,
                  _userRole == 'doctor'
                      ? 'Chats'
                      : _getTranslatedText('doctors'),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    final userId = prefs.getString('userId');
                    final token = prefs.getString('token');
                    if (userId != null && token != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DoctorsPage(
                            currentUserId: userId,
                            token: token,
                            isDoctor: _userRole == 'doctor',
                          ),
                        ),
                      );
                    }
                  },
                ),
                _buildDrawerItem(
                  Icons.location_on_outlined,
                  _getTranslatedText('AgriHealth Tracker'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HeatmapPageMap()),
                  ),
                ),
                Divider(thickness: 1, color: Colors.grey.shade300),
                _buildDrawerItem(
                  Icons.help_outline,
                  _getTranslatedText('help'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HelpPage()),
                  ),
                ),
                _buildDrawerItem(
                  Icons.logout,
                  _getTranslatedText('logout'),
                  onTap: _handleLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 26, color: Colors.grey.shade800),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade900,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade600,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      tileColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    );
  }

  Future<void> _navigateToCreateBlog(BuildContext context) async {
    // Close the drawer first
    Navigator.pop(context);

    // Navigate to create blog page and wait for result
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateBlogPage()),
    );

    // If post was created successfully
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getTranslatedText('blogPostCreated')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
