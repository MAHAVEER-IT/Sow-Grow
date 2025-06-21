import 'package:flutter/material.dart';

import '../../services/chat_service.dart' as chat_service;
import '../../services/doctor_service.dart' as doc_service;
import 'chat_screen.dart';

// This is a helper function to fix the _openChat method
void openChat(
    BuildContext context, dynamic user, String currentUserId, String token) {
  // Extract the user ID and validate it
  String receiverId = '';
  String receiverName = 'Unknown User';
  String receiverPhone = "0000000000"; // Default phone

  if (user is doc_service.Doctor) {
    receiverId = user.id;
    receiverName = user.name;
    receiverPhone = user.phone; // Get doctor's phone
  } else if (user != null) {
    receiverId = user.id ?? '';
    receiverName = user.name ?? 'Unknown User';
    // Try to get phone if available
    try {
      if (user.phone != null) {
        receiverPhone = user.phone;
      }
    } catch (e) {
      print('Phone property not available for this user type: $e');
    }
  }

  print(
      'Opening chat with receiverId: $receiverId, receiverName: $receiverName, receiverPhone: $receiverPhone');

  // Validate that we have a non-empty receiverId
  if (receiverId.isEmpty) {
    print('ERROR: Attempted to open chat with empty receiverId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot open chat: Invalid user ID')),
    );
    return;
  }

  // Create a ChatService instance
  final chatService = chat_service.ChatService();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChatScreen(
        receiverId: receiverId,
        receiverName: receiverName,
        receiverPhone: receiverPhone, // Use the extracted phone number
        currentUserId: currentUserId,
        token: token,
        chatService: chatService,
      ),
    ),
  );
}
