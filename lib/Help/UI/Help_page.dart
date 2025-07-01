import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpPage extends StatelessWidget {
  // Team member data structure
  final List<Map<String, String>> teamMembers = [
    {
      'name': 'Lingesh V',
      'role': 'Agricultural Specialist/App Developer',
      'phone': '+91 1234567890',
      'email': 'Lingesh.V@farmapp.com',
      'image': 'assets/images/aisha.jpg',
    },
    {
      'name': 'Saravanan K',
      'role': 'Technical Support/App Developer',
      'phone': '+91 12345098765',
      'email': 'Saravanan.k@farmapp.com',
      'image': 'assets/images/sarah.jpg',
    },
    {
      'name': 'Akash',
      'role': 'Technical Support/App Developer',
      'phone': '+91 0987654321',
      'email': 'Akash@farmapp.com',
      'image': 'assets/images/miguel.jpg',
    },
    {
      'name': 'Mahaveer K',
      'role': 'Technical Support/App Developer',
      'phone': '+91 9876501234',
      'email': 'Mahaveer.K@farmapp.com',
      'image': 'assets/images/robert.jpg',
    },
  ];

  // FAQs data
  final List<Map<String, String>> faqs = [
    {
      'question': 'How do I create an account?',
      'answer':
          'To create an account, tap "Sign Up" on the main screen. Fill in your details, including your name, email, phone number, and farm information. Verify your email and you\'re ready to go!'
    },
    {
      'question': 'How do I post items for sale?',
      'answer':
          'Navigate to the Marketplace tab, tap the + button, fill in your product details including photos, price, and quantity, then hit "Post".'
    },
    {
      'question': 'How can I join a local farming group?',
      'answer':
          'Go to the Communities tab, search for groups in your area or by farming type, and tap "Join". Some groups may require approval from moderators.'
    },
    {
      'question': 'How do I access weather forecasts?',
      'answer':
          'The Weather tab shows your local forecast automatically based on your location. You can add additional locations by tapping the + icon.'
    },
    {
      'question': 'How do I report a problem with the app?',
      'answer':
          'Go to Settings > Report a Problem or contact our support team directly using the contact information below.'
    },
  ];

  // Function to handle phone calls
  void _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  // Function to handle emails
  void _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Help%20Request%20from%20Farm%20App',
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: Colors.green[700],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Help options
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How can we help you?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHelpOption(
                            context,
                            Icons.article_outlined,
                            'FAQs',
                            () {
                              // Scroll to FAQs section
                              Scrollable.ensureVisible(
                                faqs.elementAt(0).context!,
                                alignment: 0.0,
                                duration: const Duration(milliseconds: 600),
                              );
                            },
                          ),
                          _buildHelpOption(
                            context,
                            Icons.people_outline,
                            'Contact Team',
                            () {
                              // Scroll to team section
                              Scrollable.ensureVisible(
                                teamContainerKey.currentContext!,
                                alignment: 0.0,
                                duration: const Duration(milliseconds: 600),
                              );
                            },
                          ),
                          _buildHelpOption(
                            context,
                            Icons.ondemand_video_outlined,
                            'Tutorials',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TutorialsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // FAQs section
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: faqs.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Text(
                        faqs[index]['question']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            faqs[index]['answer']!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Team section with key for scrolling
              Builder(
                builder: (BuildContext context) {
                  // This assigns the context to the key
                  return Column(
                    key: teamContainerKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Our Team',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: teamMembers.length,
                        itemBuilder: (context, index) {
                          final member = teamMembers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 30,
                                    backgroundColor: Colors.green[100],
                                    child: Text(
                                      member['name']!.substring(0, 1),
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member['name']!,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          member['role']!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () =>
                                              _makePhoneCall(member['phone']!),
                                          child: Row(
                                            children: [
                                              Icon(Icons.phone,
                                                  size: 16,
                                                  color: Colors.green[700]),
                                              const SizedBox(width: 8),
                                              Text(
                                                member['phone']!,
                                                style: TextStyle(
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () =>
                                              _sendEmail(member['email']!),
                                          child: Row(
                                            children: [
                                              Icon(Icons.email,
                                                  size: 16,
                                                  color: Colors.green[700]),
                                              const SizedBox(width: 8),
                                              Text(
                                                member['email']!,
                                                style: TextStyle(
                                                  color: Colors.green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // General contact information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'General Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContactInfo(Icons.access_time,
                          'Support Hours: Mon-Fri, 8AM-6PM EST'),
                      _buildContactInfo(Icons.phone, '+1 (800) FARM-APP',
                          isPhone: true),
                      _buildContactInfo(Icons.email, 'support@farmapp.com',
                          isEmail: true),
                      _buildContactInfo(Icons.location_on,
                          '123 Agriculture Road, Farm Valley, CA 94123'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSocialButton(Icons.facebook, Colors.blue),
                          _buildSocialButton(Icons.chat, Colors.green),
                          _buildSocialButton(Icons.camera_alt, Colors.purple),
                          _buildSocialButton(Icons.people, Colors.blue[700]!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // Global key for team section
  final GlobalKey teamContainerKey = GlobalKey();

  // Build help option widget
  Widget _buildHelpOption(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: Colors.green[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.green[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build contact info row
  Widget _buildContactInfo(IconData icon, String text,
      {bool isPhone = false, bool isEmail = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () {
          if (isPhone) {
            _makePhoneCall(text);
          } else if (isEmail) {
            _sendEmail(text);
          }
        },
        child: Row(
          children: [
            Icon(icon, color: Colors.green[700], size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color:
                    (isPhone || isEmail) ? Colors.green[700] : Colors.black87,
                decoration:
                    (isPhone || isEmail) ? TextDecoration.underline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build social media button
  Widget _buildSocialButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}

extension on Map<String, String> {
  get context => null;
}

// Simple placeholder tutorials page
class TutorialsPage extends StatelessWidget {
  const TutorialsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutorials'),
        backgroundColor: Colors.green[700],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildTutorialCard(
            'Getting Started with the App',
            'Learn the basics of navigation and setting up your profile',
            '5:32',
          ),
          _buildTutorialCard(
            'Posting Products for Sale',
            'How to create attractive listings that sell quickly',
            '4:18',
          ),
          _buildTutorialCard(
            'Analyzing Weather Forecasts',
            'Making the most of our detailed weather predictions',
            '7:45',
          ),
          _buildTutorialCard(
            'Connecting with Other Farmers',
            'Building your network in the farming community',
            '3:56',
          ),
          _buildTutorialCard(
            'Setting Up Crop Alerts',
            'Get notified about important events for your crops',
            '6:21',
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialCard(String title, String description, String duration) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            width: double.infinity,
            color: Colors.green[100],
            child: Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.green[700],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        duration,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Watch Tutorial'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
