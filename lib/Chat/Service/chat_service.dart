import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ChatUser {
  final String id;
  final String name;
  final String profilePic;

  ChatUser({
    required this.id,
    required this.name,
    required this.profilePic,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    print('Parsing ChatUser from JSON: $json');
    return ChatUser(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      profilePic: json['profilePic'] ?? '',
    );
  }
}

class ChatMessage {
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] ?? json['message'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ??
          json['createdAt'] ??
          DateTime.now().toIso8601String()),
    );
  }
}

class ChatHistory {
  final ChatUser user;
  final ChatMessage? lastMessage;
  final int unreadCount;

  ChatHistory({
    required this.user,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    print('Parsing ChatHistory from JSON: $json');
    return ChatHistory(
      user: ChatUser.fromJson(json['user'] ?? {}),
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class ChatService {
  static const String baseUrl =
      'https://farmcare-backend-new.onrender.com/api/v1'; // Updated to match backend routes
  static const String socketUrl =
      'https://farmcare-backend-new.onrender.com'; // Socket URL remains the same
  IO.Socket? socket;
  Function(Map<String, dynamic>)? onNewMessage;
  Function(List<String>)? onOnlineUsersUpdate;
  String? _currentSocketUserId; // Track the current user ID

  // Map to store mock messages between users
  final Map<String, List<Map<String, dynamic>>> _mockMessages = {};

  // Updated endpoints to match backend routes
  static const String sendMessageEndpoint = '/message/send';
  static const String getChatHistoryEndpoint = '/message/history/';
  static const String getDoctorChatsEndpoint = '/message/doctor/chats';

  void connectSocket(String userId) {
    try {
      print('========== CONNECTING SOCKET ==========');
      print('Connecting socket for userId: $userId');

      // Only disconnect if we're connecting with a different user ID
      if (socket != null) {
        if (_currentSocketUserId == userId && socket!.connected) {
          print(
              'Socket already connected with userId: $userId, reusing connection');
          return;
        }

        // Disconnect existing socket if it's for a different user
        print('Disconnecting existing socket for different user');
        disconnectSocket();
      }

      _currentSocketUserId = userId; // Store the user ID

      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'query': {'userId': userId},
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionAttempts': 10,
        'timeout': 10000,
      });

      socket!.onConnect((_) {
        print('Socket connected with userId: $userId');

        // Join user's room for private messages - this is critical
        socket!.emit('join', {'userId': userId});
        print('Joined room for userId: $userId');

        // Also emit the join event without wrapping in an object (for compatibility)
        socket!.emit('join', userId);
        print('Also joined room with direct userId: $userId');

        // Join additional room formats
        socket!.emit('join_user', userId);
        socket!.emit('join_user', {'userId': userId});
        print('Joined additional room formats');

        // Emit a connection acknowledgment request
        socket!.emit('connection_ack', {'userId': userId});
        print('Requested connection acknowledgment');

        // Request pending messages
        socket!.emit('request_pending_messages', {'userId': userId});
        print('Requested pending messages');

        // Force a direct connection to the server's socket namespace
        socket!.emit('force_connect', {'userId': userId});
        print('Forced direct connection to socket namespace');
      });

      // Listen for all possible message event names
      _setupMessageListener('newMessage');
      _setupMessageListener('receive_message');
      _setupMessageListener('message');
      _setupMessageListener('private_message');
      _setupMessageListener('direct_message');
      _setupMessageListener('chat_message');
      _setupMessageListener('room_message');
      _setupMessageListener('message_text');
      _setupMessageListener('message_json');

      // Add a special listener for any event (catch-all)
      socket!.onAny((event, data) {
        print('Received ANY event: $event');
        print('Event data: $data');

        // If this is a message-related event we're not explicitly handling, process it
        if (event.toString().contains('message') && onNewMessage != null) {
          try {
            Map<String, dynamic> message;
            if (data is Map) {
              message = Map<String, dynamic>.from(data);
            } else if (data is String) {
              try {
                message = json.decode(data);
              } catch (e) {
                message = {
                  'content': data,
                  'timestamp': DateTime.now().toIso8601String()
                };
              }
            } else {
              return; // Can't process this format
            }

            print('Processing unhandled message event: $event');
            print('Message data: $message');
            onNewMessage!(message);
          } catch (e) {
            print('Error processing unhandled message event: $e');
          }
        }
      });

      socket!.on('getOnlineUsers', (data) {
        try {
          print('Received online users: $data');
          if (onOnlineUsersUpdate != null && data is List) {
            onOnlineUsersUpdate!(List<String>.from(data));
          }
        } catch (e) {
          print('Error handling online users update: $e');
        }
      });

      socket!.on('connect_ack', (data) {
        print('Received connection acknowledgment: $data');
      });

      socket!.on('pending_messages', (data) {
        print('Received pending messages: $data');
        try {
          if (data is List) {
            for (var msg in data) {
              if (onNewMessage != null) {
                onNewMessage!(Map<String, dynamic>.from(msg));
              }
            }
          }
        } catch (e) {
          print('Error handling pending messages: $e');
        }
      });

      socket!.onDisconnect((_) => print('Socket disconnected'));
      socket!.onError((err) => print('Socket error: $err'));
      socket!.onConnectError((err) => print('Socket connect error: $err'));

      print('========== FINISHED CONNECTING SOCKET ==========');
    } catch (e) {
      print('Error setting up socket connection: $e');
      print(e.toString());
    }
  }

  void _setupMessageListener(String eventName) {
    socket!.on(eventName, (data) {
      try {
        print('========== RECEIVED $eventName EVENT ==========');
        print('Received $eventName event with data type: ${data.runtimeType}');
        print('Received $eventName event data: $data');

        Map<String, dynamic> message;

        // Handle different message formats
        if (data is Map) {
          message = Map<String, dynamic>.from(data);
          print('Message is a Map, converted to: $message');
        } else if (data is String) {
          // Try to parse string as JSON
          try {
            message = json.decode(data);
            print('Message is a String, parsed JSON: $message');
          } catch (e) {
            print('Error parsing string message: $e');
            message = {
              'content': data,
              'timestamp': DateTime.now().toIso8601String()
            };
            print('Created fallback message: $message');
          }
        } else {
          print('Unhandled message format: ${data.runtimeType}');
          print('========== END $eventName EVENT (ERROR) ==========');
          return;
        }

        // Check if this is a private message wrapper
        if (message.containsKey('message') && message['message'] is Map) {
          print('Unwrapping nested message from: $message');
          message = Map<String, dynamic>.from(message['message']);
          print('Unwrapped to: $message');
        }

        // Check if this is a room message
        if (message.containsKey('room') &&
            message.containsKey('message') &&
            message['message'] is Map) {
          print('Unwrapping room message from: $message');
          message = Map<String, dynamic>.from(message['message']);
          print('Unwrapped room message to: $message');
        }

        // Check if this is a 'to/from' format
        if (message.containsKey('to') && message.containsKey('from')) {
          print('Found to/from format message: $message');
          // Create a standard format message
          final content = message['content'] ?? message['message'] ?? '';
          final timestamp =
              message['timestamp'] ?? DateTime.now().toIso8601String();
          message = {
            'senderId': message['from'],
            'receiverId': message['to'],
            'content': content,
            'timestamp': timestamp,
          };
          print('Converted to standard format: $message');
        }

        // Check for content field
        if (!message.containsKey('content') &&
            message.containsKey('message') &&
            message['message'] is String) {
          print('Converting message field to content: ${message['message']}');
          message['content'] = message['message'];
        }

        // Check if we have the necessary fields
        if (!message.containsKey('content') &&
            !message.containsKey('message')) {
          print('Message has no content or message field, skipping');
          print('========== END $eventName EVENT (NO CONTENT) ==========');
          return;
        }

        print('Processed message: $message');

        if (onNewMessage != null) {
          // Ensure the message has an ID to prevent duplicates
          if (!message.containsKey('_id')) {
            message['_id'] =
                '${message['senderId'] ?? ''}_${message['content'] ?? message['message'] ?? ''}_${DateTime.now().millisecondsSinceEpoch}';
            print('Generated message ID: ${message['_id']}');
          }

          print('Calling onNewMessage callback with message');
          onNewMessage!(message);
        } else {
          print('No onNewMessage callback registered');
        }

        print('========== END $eventName EVENT ==========');
      } catch (e) {
        print('Error handling $eventName: $e');
        print(e.toString());
        print('========== END $eventName EVENT (ERROR) ==========');
      }
    });
  }

  void disconnectSocket() {
    try {
      if (socket != null) {
        socket!.disconnect();
        socket!.dispose();
        socket = null;
        _currentSocketUserId = null; // Clear the user ID
      }
    } catch (e) {
      print('Error disconnecting socket: $e');
      socket = null;
      _currentSocketUserId = null; // Clear the user ID even on error
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      throw Exception('Not authenticated');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final headers = await _getHeaders();
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        throw Exception('User ID not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        throw Exception('Failed to load conversations');
      }
    } catch (e) {
      throw Exception('Error getting conversations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(
      String receiverId, String token) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      // Use the correct endpoint with the defined constant
      final response = await http.get(
        Uri.parse('$baseUrl$getChatHistoryEndpoint$receiverId'),
        headers: headers,
      );

      print('Fetching messages - Status: ${response.statusCode}');
      print(
          'Fetching messages - URL: $baseUrl$getChatHistoryEndpoint$receiverId');
      print('Fetching messages - Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // Check if the response has the expected structure
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          return List<Map<String, dynamic>>.from(data);
        } else {
          print('API response format unexpected: $responseData');
        }
      }

      print('Failed to fetch messages, using mock data');
      return _getMockMessages(receiverId);
    } catch (e) {
      print('Error fetching messages: $e');
      return _getMockMessages(receiverId);
    }
  }

  Future<List<Map<String, dynamic>>> _getMockMessages(String receiverId) async {
    // Get the current user ID
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'user1';

    // Create a unique conversation ID (combination of both user IDs)
    final conversationId = [userId, receiverId]..sort();
    final convId = conversationId.join('_');

    // If no messages exist for this conversation, create some initial ones
    if (!_mockMessages.containsKey(convId)) {
      _mockMessages[convId] = [];

      // Add some initial messages if this is a doctor
      if (receiverId.startsWith('doc')) {
        final now = DateTime.now();

        // Format dates properly with leading zeros for consistent parsing
        final yesterday = now.subtract(Duration(days: 1));
        final yesterdayStr =
            "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}T${yesterday.hour.toString().padLeft(2, '0')}:${yesterday.minute.toString().padLeft(2, '0')}:00.000Z";

        _mockMessages[convId] = [
          {
            'senderId': receiverId,
            'receiverId': userId,
            'content': 'Hello! How can I help you today?',
            'timestamp': yesterdayStr,
            '_id': 'mock_1',
          },
          {
            'senderId': userId,
            'receiverId': receiverId,
            'content': 'Hi doctor, I have some questions about my livestock.',
            'timestamp': yesterdayStr,
            '_id': 'mock_2',
          },
          {
            'senderId': receiverId,
            'receiverId': userId,
            'content':
                'Sure, I\'d be happy to help. What specific concerns do you have?',
            'timestamp': yesterdayStr,
            '_id': 'mock_3',
          },
        ];
      }
    }

    return _mockMessages[convId] ?? [];
  }

  Future<Map<String, dynamic>> sendMessage(
      String receiverId, String content, String token, String userId,
      [String? clientId]) async {
    try {
      print('========== SENDING MESSAGE VIA CHAT SERVICE ==========');
      final message = {
        'receiverId': receiverId,
        'content': content,
      };

      // Add clientId if provided to help server deduplicate
      if (clientId != null) {
        message['clientId'] = clientId;
      }

      print('Sending message to $receiverId: $content');
      print('Using endpoint: $baseUrl$sendMessageEndpoint');

      // Make sure we're in a room with the receiver
      if (socket != null && socket!.connected) {
        print('Socket is connected, sending message via socket');

        // Join a chat room with the receiver - try multiple formats for compatibility
        socket!.emit('join_chat', {
          'userId': userId,
          'receiverId': receiverId,
        });

        // Also try joining with just the IDs
        socket!.emit('join_chat', '$userId-$receiverId');

        // Also try reversed IDs
        socket!.emit('join_chat', '$receiverId-$userId');

        // And try the direct join format
        socket!.emit('join', receiverId);

        print('Joined chat room with receiver: $receiverId');

        // Emit message through socket with all necessary fields
        final socketMessage = {
          'senderId': userId,
          'receiverId': receiverId,
          'content': content,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Add clientId if provided to help server deduplicate
        if (clientId != null) {
          socketMessage['clientId'] = clientId;
        }

        // Send with the most reliable format based on your server implementation
        socket!.emit('send_message', socketMessage);
        print('Emitted with send_message event');

        // Also try the private message format as a backup
        socket!.emit(
            'private_message', {'to': receiverId, 'message': socketMessage});
        print('Emitted with private_message event');
      } else {
        print('Socket not connected, skipping socket message');
      }

      // Try HTTP endpoint as fallback
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.post(
        Uri.parse('$baseUrl$sendMessageEndpoint'),
        headers: headers,
        body: json.encode(message),
      );

      print('Send message response status: ${response.statusCode}');
      print('Send message response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          // If we got a successful response, also emit this message via socket
          // to ensure it's delivered in real-time
          if (socket != null && socket!.connected) {
            final serverMessage = responseData['data'];

            // Emit with the most reliable format based on your server implementation
            socket!.emit('receive_message', serverMessage);
            print('Re-emitted server message via socket');
          }

          print(
              '========== FINISHED SENDING MESSAGE VIA CHAT SERVICE ==========');
          return responseData['data'];
        }
      }

      // If API call fails, use mock data
      print('API call failed, using mock data');
      final mockMessage =
          await _storeMockMessage(receiverId, content, userId, clientId);
      print(
          '========== FINISHED SENDING MESSAGE VIA CHAT SERVICE (MOCK) ==========');
      return mockMessage;
    } catch (e) {
      print('Error sending message: $e');
      print('Using mock data due to error');
      final mockMessage =
          await _storeMockMessage(receiverId, content, userId, clientId);
      print(
          '========== FINISHED SENDING MESSAGE VIA CHAT SERVICE (ERROR) ==========');
      return mockMessage;
    }
  }

  Future<Map<String, dynamic>> _storeMockMessage(
      String receiverId, String content, String userId,
      [String? clientId]) async {
    // Create a unique conversation ID (combination of both user IDs)
    final conversationId = [userId, receiverId]..sort();
    final convId = conversationId.join('_');

    // Format date properly with leading zeros
    final now = DateTime.now();
    final formattedDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.000Z";

    // Create the message with the correct field names
    final message = {
      'senderId': userId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': formattedDate,
      '_id': clientId ?? 'mock_${DateTime.now().millisecondsSinceEpoch}',
    };

    // Add clientId if provided to help server deduplicate
    if (clientId != null) {
      message['clientId'] = clientId;
    }

    // Initialize the conversation if it doesn't exist
    _mockMessages[convId] ??= [];

    // Add the message to the conversation
    _mockMessages[convId]!.add(message);

    // Simulate a delay to make it feel like a network request
    await Future.delayed(Duration(milliseconds: 300));

    // Notify listeners if socket is connected
    if (socket != null && socket!.connected) {
      print('Emitting mock message via socket');

      // Send with the most reliable format based on your server implementation
      socket!.emit('receive_message', message);
      print('Emitted with receive_message event');

      // Also try the private message format as a backup
      socket!.emit('private_message', {'to': receiverId, 'message': message});
      print('Emitted with private_message event');

      print('Finished emitting mock message via socket');
    } else {
      print('Socket not connected, skipping socket emission');
    }

    return message;
  }

  Future<bool> isServerReachable() async {
    try {
      print('Checking server connectivity at: $socketUrl');

      // First try the health endpoint
      try {
        final response = await http
            .get(Uri.parse('$socketUrl/health'))
            .timeout(Duration(seconds: 3));

        print('Server health check response: ${response.statusCode}');
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        print('Health endpoint check failed: $e');
        // Continue to try the root endpoint
      }

      // If health endpoint fails, try the root endpoint
      try {
        final response =
            await http.get(Uri.parse(socketUrl)).timeout(Duration(seconds: 3));

        print('Server root endpoint response: ${response.statusCode}');
        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (e) {
        print('Root endpoint check failed: $e');
        return false;
      }
    } catch (e) {
      print('Server connectivity check failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    try {
      final headers = await _getHeaders();

      // Update the endpoint to match your backend API
      final response = await http
          .get(
            Uri.parse('$baseUrl/doctors'), // Updated endpoint
            headers: headers,
          )
          .timeout(Duration(seconds: 10));

      print('Fetching doctors - Status: ${response.statusCode}');
      print('Response: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isEmpty) {
          print('No doctors found in database, returning mock data');
          return _getMockDoctors();
        }

        // Transform the data to match expected format
        return data.map<Map<String, dynamic>>((doctor) {
          return {
            '_id': doctor['_id'] ?? doctor['id'] ?? '',
            'name': doctor['name'] ?? '',
            'username': doctor['username'] ?? '',
            'email': doctor['email'] ?? '',
            'userType': doctor['userType'] ?? 'doctor',
            'location': doctor['location'] ?? '',
            'specialization': doctor['specialization'] ?? '',
            'experience': doctor['experience'] ?? '',
          };
        }).toList();
      }

      print('Failed to fetch doctors, status: ${response.statusCode}');
      return _getMockDoctors();
    } catch (e) {
      print('Error fetching doctors: $e');
      return _getMockDoctors();
    }
  }

  List<Map<String, dynamic>> _getMockDoctors() {
    // Return some mock data for testing
    return [
      {
        '_id': 'doc1',
        'name': 'Dr. Rajesh Kumar',
        'username': 'rajesh_vet',
        'email': 'rajesh@example.com',
        'userType': 'doctor',
        'location': 'Chennai, Tamil Nadu',
        'specialization': 'Livestock Health',
        'experience': '10 years'
      },
      {
        '_id': 'doc2',
        'name': 'Dr. Priya Singh',
        'username': 'priya_vet',
        'email': 'priya@example.com',
        'userType': 'doctor',
        'location': 'Coimbatore, Tamil Nadu',
        'specialization': 'Dairy Animals',
        'experience': '8 years'
      },
      {
        '_id': 'doc3',
        'name': 'Dr. Anand Sharma',
        'username': 'anand_vet',
        'email': 'anand@example.com',
        'userType': 'doctor',
        'location': 'Madurai, Tamil Nadu',
        'specialization': 'Poultry',
        'experience': '5 years'
      },
      {
        '_id': 'doc4',
        'name': 'Dr. Lakshmi Nair',
        'username': 'lakshmi_vet',
        'email': 'lakshmi@example.com',
        'userType': 'doctor',
        'location': 'Salem, Tamil Nadu',
        'specialization': 'General Veterinary',
        'experience': '12 years'
      },
    ];
  }

  Future<List<ChatHistory>> getChats(String token) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      print('Fetching chats with token');
      print('Using endpoint: $baseUrl$getDoctorChatsEndpoint');

      final response = await http.get(
        Uri.parse('$baseUrl$getDoctorChatsEndpoint'),
        headers: headers,
      );

      print('Fetching chats - Status: ${response.statusCode}');
      print('Fetching chats - Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> data = responseData['data'];
          print('Successfully parsed ${data.length} chat histories');

          // Process each chat history item
          final List<ChatHistory> result = [];
          for (var item in data) {
            try {
              final chatHistory = ChatHistory.fromJson(item);
              print(
                  'Processed chat history with user id: ${chatHistory.user.id}, name: ${chatHistory.user.name}');
              result.add(chatHistory);
            } catch (e) {
              print('Error processing chat history item: $e');
              print('Problematic item: $item');
            }
          }

          return result;
        } else {
          print('API response format unexpected: $responseData');
        }
      }

      // Return empty list if API fails
      print('Failed to fetch chats, returning empty list');
      return [];
    } catch (e) {
      print('Error fetching chats: $e');
      return [];
    }
  }

  /// Checks if the socket is connected
  bool isSocketConnected() {
    if (socket == null) {
      print('Socket is null, not connected');
      return false;
    }

    final connected = socket!.connected;
    print('Socket connection status: $connected');
    return connected;
  }

  // Add new method for image upload
  Future<String> uploadChatImage(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Validate file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      // Validate file size (5MB limit)
      final length = await imageFile.length();
      if (length > 5 * 1024 * 1024) {
        throw Exception(
            'Image size too large. Please choose an image under 5MB.');
      }

      // Validate file type
      final mimeType = lookupMimeType(imageFile.path);
      if (mimeType == null || !mimeType.startsWith('image/')) {
        throw Exception('Invalid file type. Please choose an image file.');
      }

      // Create upload request
      final uri = Uri.parse('$baseUrl/photos/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          'Authorization':
              token.startsWith('Bearer ') ? token : 'Bearer $token',
          'Accept': 'application/json',
        });

      // Add file to request
      final stream = http.ByteStream(imageFile.openRead());
      final multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
        contentType: MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
      );
      request.files.add(multipartFile);

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['imageUrl'] != null) {
          return data['imageUrl'];
        }
        throw Exception('No image URL in response');
      }

      throw Exception('Failed to upload image: ${response.statusCode}');
    } catch (e) {
      print('Image upload error: $e');
      rethrow;
    }
  }

  // Add new method for sending image message
  Future<Map<String, dynamic>> sendImageMessage({
    required String receiverId,
    required File imageFile,
  }) async {
    try {
      // First upload the image
      final imageUrl = await uploadChatImage(imageFile);

      // Then send the message with the image URL
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/message/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              token.startsWith('Bearer ') ? token : 'Bearer $token',
        },
        body: json.encode({
          'receiverId': receiverId,
          'content': imageUrl,
          'messageType': 'image',
          'type': 'image',
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data is Map) {
          data['messageType'] = 'image';
        }
        return {'success': true, 'data': data};
      }

      throw Exception('Failed to send image message: ${response.statusCode}');
    } catch (e) {
      print('Send image message error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Add new method for voice message upload
  Future<String> uploadVoiceMessage(File audioFile) async {
    int maxRetries = 3;
    int currentRetry = 0;
    Duration retryDelay = Duration(seconds: 2);

    // Cloudinary configuration
    const cloudName = 'dkn3it92b';
    const uploadPreset = 'mahaveer'; // Your upload preset from Cloudinary

    while (currentRetry < maxRetries) {
      try {
        // Validate file exists
        if (!await audioFile.exists()) {
          throw Exception('Audio file not found');
        }

        // Validate file size (10MB limit for audio)
        final length = await audioFile.length();
        if (length > 10 * 1024 * 1024) {
          throw Exception('Audio size too large. Please keep it under 10MB.');
        }

        // Validate file type
        final mimeType = lookupMimeType(audioFile.path);
        if (mimeType == null || !mimeType.startsWith('audio/')) {
          throw Exception('Invalid file type. Please select an audio file.');
        }

        // Create upload request to Cloudinary using upload preset
        final uri =
            Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/auto/upload');
        final request = http.MultipartRequest('POST', uri)
          ..fields.addAll({
            'upload_preset': uploadPreset,
            'resource_type':
                'auto', // This will automatically detect audio files
            'folder': 'voice_messages', // Optional: organize files in a folder
          });

        // Add file to request
        final stream = http.ByteStream(audioFile.openRead());
        final multipartFile = http.MultipartFile(
          'file',
          stream,
          length,
          filename: audioFile.path.split('/').last,
          contentType:
              MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
        );
        request.files.add(multipartFile);

        print('Starting audio upload attempt ${currentRetry + 1}...');
        print('File size: ${length / 1024 / 1024}MB');
        print('MIME type: $mimeType');

        // Send request with timeout
        final streamedResponse =
            await request.send().timeout(Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);

        print('Upload response status: ${response.statusCode}');
        print('Upload response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['secure_url'] != null) {
            return data['secure_url'];
          }
          throw Exception('No URL in response');
        }

        // Handle specific error cases
        if (response.statusCode == 503) {
          throw Exception(
              'Cloudinary is temporarily unavailable. Please try again later.');
        } else if (response.statusCode == 401) {
          throw Exception(
              'Upload preset authentication failed. Please check your configuration.');
        }

        throw Exception('Failed to upload audio: ${response.statusCode}');
      } catch (e) {
        currentRetry++;
        print('Upload attempt $currentRetry failed with error: $e');

        if (currentRetry >= maxRetries) {
          print('Failed to upload audio after $maxRetries attempts: $e');
          rethrow;
        }

        print('Retrying in ${retryDelay.inSeconds} seconds...');
        await Future.delayed(retryDelay);
        // Exponential backoff
        retryDelay *= 2;
      }
    }
    throw Exception('Failed to upload audio after $maxRetries attempts');
  }

  // Add new method for sending voice message
  Future<Map<String, dynamic>> sendVoiceMessage({
    required String receiverId,
    required File audioFile,
    required Duration duration,
  }) async {
    try {
      // First upload the audio file
      String audioUrl;
      try {
        audioUrl = await uploadVoiceMessage(audioFile);
      } catch (e) {
        print('Failed to upload audio file: $e');
        return {
          'success': false,
          'message':
              'Failed to upload audio. Please check your connection and try again.',
          'error': e.toString()
        };
      }

      // Then send the message with the audio URL
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        return {
          'success': false,
          'message': 'Authentication failed. Please log in again.',
          'error': 'Not authenticated'
        };
      }

      final response = await http.post(
        Uri.parse('$baseUrl/message/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              token.startsWith('Bearer ') ? token : 'Bearer $token',
        },
        body: json.encode({
          'receiverId': receiverId,
          'content': audioUrl,
          'messageType': 'voice',
          'type': 'voice',
          'audioDuration': duration.inSeconds,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data is Map) {
          data['messageType'] = 'voice';
          data['audioDuration'] = duration.inSeconds;
        }
        return {'success': true, 'data': data};
      }

      // Handle specific error cases
      if (response.statusCode == 503) {
        return {
          'success': false,
          'message':
              'Server is temporarily unavailable. Please try again later.',
          'error': '503 Service Unavailable'
        };
      } else if (response.statusCode == 502) {
        return {
          'success': false,
          'message': 'Bad gateway. Please try again later.',
          'error': '502 Bad Gateway'
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Authentication failed. Please log in again.',
          'error': '401 Unauthorized'
        };
      }

      return {
        'success': false,
        'message': 'Failed to send voice message. Please try again.',
        'error': 'Status code: ${response.statusCode}'
      };
    } catch (e) {
      print('Send voice message error: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
        'error': e.toString()
      };
    }
  }

  void _handleIncomingMessage(dynamic data,
      {required String currentUserId, required String receiverId}) {
    try {
      print('========== HANDLING INCOMING MESSAGE ==========');
      print('Received message data type: ${data.runtimeType}');
      print('Received message data: $data');

      Map<String, dynamic> message;

      // Handle different message formats
      if (data is Map) {
        message = Map<String, dynamic>.from(data);
        print('Message is a Map, converted to: $message');

        // Handle nested data structure from server response
        if (message.containsKey('success') && message.containsKey('data')) {
          print('Found nested data structure, extracting message data');
          message = Map<String, dynamic>.from(message['data']);
        }
      } else if (data is String) {
        // Try to parse string as JSON
        try {
          message = json.decode(data);
          print('Message is a String, parsed JSON: $message');
        } catch (e) {
          print('Error parsing string message: $e');
          message = {
            'content': data,
            'timestamp': DateTime.now().toIso8601String()
          };
          print('Created fallback message: $message');
        }
      } else {
        print('Unhandled message format: ${data.runtimeType}');
        print('========== END HANDLING INCOMING MESSAGE (ERROR) ==========');
        return;
      }

      // Check if this is a private message wrapper
      if (message.containsKey('message') && message['message'] is Map) {
        print('Unwrapping nested message from: $message');
        message = Map<String, dynamic>.from(message['message']);
        print('Unwrapped to: $message');
      }

      // Check if this is a room message
      if (message.containsKey('room') &&
          message.containsKey('message') &&
          message['message'] is Map) {
        print('Unwrapping room message from: $message');
        message = Map<String, dynamic>.from(message['message']);
        print('Unwrapped room message to: $message');
      }

      // Check if this is a 'to/from' format
      if (message.containsKey('to') && message.containsKey('from')) {
        print('Found to/from format message: $message');
        // Create a standard format message
        final content = message['content'] ?? message['message'] ?? '';
        final timestamp =
            message['timestamp'] ?? DateTime.now().toIso8601String();
        message = {
          'senderId': message['from'],
          'receiverId': message['to'],
          'content': content,
          'timestamp': timestamp,
        };
        print('Converted to standard format: $message');
      }

      // Check for content field
      if (!message.containsKey('content') &&
          message.containsKey('message') &&
          message['message'] is String) {
        print('Converting message field to content: ${message['message']}');
        message['content'] = message['message'];
      }

      // Check if we have the necessary fields
      if (!message.containsKey('content') && !message.containsKey('message')) {
        print('Message has no content or message field, skipping');
        print(
            '========== END HANDLING INCOMING MESSAGE (NO CONTENT) ==========');
        return;
      }

      // Ensure we have sender and receiver IDs
      final senderId = message['senderId'] ?? '';
      final receiverId = message['receiverId'] ?? '';

      print('Message senderId: $senderId, receiverId: $receiverId');
      print(
          'Current chat: currentUserId: $currentUserId, receiverId: $receiverId');

      // Check if this message is for the current chat
      bool isForCurrentChat = false;

      // Check if the message is between the current sender and receiver
      if ((senderId == receiverId && receiverId == currentUserId) ||
          (senderId == currentUserId && receiverId == receiverId)) {
        isForCurrentChat = true;
        print('Message is for current chat');
      } else {
        print('Message is NOT for current chat, ignoring');
        print('Sender ID match: ${senderId == receiverId}');
        print('Receiver ID match: ${receiverId == currentUserId}');
        print('Reverse sender match: ${senderId == currentUserId}');
        print('Reverse receiver match: ${receiverId == receiverId}');
        print('========== END HANDLING INCOMING MESSAGE (IGNORED) ==========');
        return;
      }

      print('Processed message: $message');

      if (onNewMessage != null) {
        // Ensure the message has an ID to prevent duplicates
        if (!message.containsKey('_id')) {
          message['_id'] =
              '${message['senderId'] ?? ''}_${message['content'] ?? message['message'] ?? ''}_${DateTime.now().millisecondsSinceEpoch}';
          print('Generated message ID: ${message['_id']}');
        }

        print('Calling onNewMessage callback with message');
        onNewMessage!(message);
      } else {
        print('No onNewMessage callback registered');
      }

      print('========== END HANDLING INCOMING MESSAGE ==========');
    } catch (e) {
      print('Error handling incoming message: $e');
      print(e.toString());
      print('========== END HANDLING INCOMING MESSAGE (ERROR) ==========');
    }
  }
}
