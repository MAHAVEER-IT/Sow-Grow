import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:sow_and_grow/services/chat_service.dart';
import 'package:sow_and_grow/utils/app_localizations.dart';
import 'package:sow_and_grow/utils/language_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverPhone;
  final String currentUserId;
  final String token;
  final ChatService chatService;

  const ChatScreen({
    Key? key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverPhone,
    required this.currentUserId,
    required this.token,
    required this.chatService,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _error;
  List<String> _onlineUsers = [];
  final Set<String> _processedMessageIds = {};
  late IO.Socket socket;
  bool _isConnected = false;
  bool _isSending = false;
  String? _lastMessageTimestamp;
  final Random _random = Random();
  bool _isUploadingImage = false;
  FlutterSoundRecorder? _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  FlutterSoundPlayer? _audioPlayer;
  String? _currentlyPlayingMessageId;

  @override
  void initState() {
    super.initState();

    // Register callback for new messages from ChatService
    widget.chatService.onNewMessage = (message) {
      print('Received message from ChatService: $message');
      _handleIncomingMessage(message);
    };

    _initSocket();
    _loadMessages();
    _initAudioRecorder();

    // Set up periodic connection check
    Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) {
        if (!_isConnected) {
          print('Periodic reconnection check - reconnecting socket');
          socket.connect();
        }

        // Also periodically poll for new messages as a fallback
        _pollForNewMessages();
      } else {
        timer.cancel();
      }
    });
  }

  void _initSocket() {
    try {
      print('========== INITIALIZING SOCKET ==========');
      print('Initializing socket for userId: ${widget.currentUserId}');

      // Initialize socket with proper options
      socket = IO.io(
        'https://farmcare-backend-new.onrender.com',
        <String, dynamic>{
          'transports': ['websocket', 'polling'],
          'autoConnect': false,
          'forceNew': true,
          'query': {
            'userId': widget.currentUserId,
            'token': widget.token,
            'chatWith': widget.receiverId,
          },
          'reconnection': true,
          'reconnectionDelay': 1000,
          'reconnectionAttempts': 10,
          'timeout': 10000,
        },
      );

      socket.onConnect((_) {
        print('Socket connected successfully');
        setState(() => _isConnected = true);

        // Join rooms for this chat
        _joinChatRooms();

        // Also connect the ChatService socket to ensure both are connected
        widget.chatService.connectSocket(widget.currentUserId);

        // Request server to send any pending messages
        socket.emit('request_pending_messages', {
          'userId': widget.currentUserId,
          'receiverId': widget.receiverId,
        });

        // Notify server about active chat
        socket.emit('active_chat', {
          'userId': widget.currentUserId,
          'receiverId': widget.receiverId,
        });
      });

      socket.onDisconnect((_) {
        print('Socket disconnected');
        setState(() => _isConnected = false);
      });

      socket.onConnectError(
        (error) => print('Socket connection error: $error'),
      );
      socket.onError((error) => print('Socket error: $error'));

      // Listen for all possible message events
      _setupSocketListeners();

      // Connect the socket
      print('Connecting socket...');
      socket.connect();

      // Start periodic connection check
      _startSocketCheck();

      print('========== FINISHED INITIALIZING SOCKET ==========');
    } catch (e) {
      print('Error initializing socket: $e');
      print(e.toString());
    }
  }

  void _joinChatRooms() {
    try {
      print('========== JOINING CHAT ROOMS ==========');

      // Join user's own room
      print('Joining own room: ${widget.currentUserId}');
      socket.emit('join', {'userId': widget.currentUserId});
      socket.emit('join', widget.currentUserId);

      // Join receiver's room
      print('Joining receiver room: ${widget.receiverId}');
      socket.emit('join', {'userId': widget.receiverId});
      socket.emit('join', widget.receiverId);

      // Create room IDs for different formats
      final directRoom = '${widget.currentUserId}-${widget.receiverId}';
      final reverseRoom = '${widget.receiverId}-${widget.currentUserId}';
      final combinedRoom = [widget.currentUserId, widget.receiverId]..sort();
      final sortedRoom = combinedRoom.join('-');

      // Also create underscore versions
      final directRoomUnderscore = directRoom.replaceAll('-', '_');
      final reverseRoomUnderscore = reverseRoom.replaceAll('-', '_');
      final sortedRoomUnderscore = sortedRoom.replaceAll('-', '_');

      // Join direct room
      print('Joining direct room: $directRoom');
      socket.emit('join_room', {'room': directRoom});
      socket.emit('join_chat', {'room': directRoom});
      socket.emit('join_chat', directRoom);
      socket.emit('join', directRoom);

      // Join reverse room
      print('Joining reverse room: $reverseRoom');
      socket.emit('join_room', {'room': reverseRoom});
      socket.emit('join_chat', {'room': reverseRoom});
      socket.emit('join_chat', reverseRoom);
      socket.emit('join', reverseRoom);

      // Join sorted room
      print('Joining sorted room: $sortedRoom');
      socket.emit('join_room', {'room': sortedRoom});
      socket.emit('join_chat', {'room': sortedRoom});
      socket.emit('join_chat', sortedRoom);
      socket.emit('join', sortedRoom);

      // Join underscore versions
      print('Joining underscore rooms');
      socket.emit('join_room', {'room': directRoomUnderscore});
      socket.emit('join_room', {'room': reverseRoomUnderscore});
      socket.emit('join_room', {'room': sortedRoomUnderscore});
      socket.emit('join', directRoomUnderscore);
      socket.emit('join', reverseRoomUnderscore);
      socket.emit('join', sortedRoomUnderscore);

      // Join private chat room
      print('Joining private chat room');
      socket.emit('join_private_chat', {
        'userId': widget.currentUserId,
        'receiverId': widget.receiverId,
      });

      // Request acknowledgment
      socket.emit('check_rooms', (rooms) {
        print('Rooms joined: $rooms');
      });

      print('========== FINISHED JOINING CHAT ROOMS ==========');
    } catch (e) {
      print('Error joining chat rooms: $e');
      print(e.toString());
    }
  }

  void _setupSocketListeners() {
    try {
      print('========== SETTING UP SOCKET LISTENERS ==========');

      // Listen for all possible message event names
      socket.on('receive_message', (data) {
        print('Received receive_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('newMessage', (data) {
        print('Received newMessage event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('message', (data) {
        print('Received message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('private_message', (data) {
        print('Received private_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('direct_message', (data) {
        print('Received direct_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('room_message', (data) {
        print('Received room_message event: $data');
        _handleIncomingMessage(data);
      });

      socket.on('chat_message', (data) {
        print('Received chat_message event: $data');
        _handleIncomingMessage(data);
      });

      // Listen for online users updates
      socket.on('getOnlineUsers', (data) {
        print('Received online users update: $data');
        if (mounted && data is List) {
          setState(() {
            _onlineUsers = List<String>.from(data);
          });
        }
      });

      print('========== FINISHED SETTING UP SOCKET LISTENERS ==========');
    } catch (e) {
      print('Error setting up socket listeners: $e');
      print(e.toString());
    }
  }

  void _handleIncomingMessage(dynamic data) {
    try {
      print('========== HANDLING INCOMING MESSAGE ==========');
      print('Received message data type: ${data.runtimeType}');
      print('Received message data: $data');

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
            'timestamp': DateTime.now().toIso8601String(),
            'senderId': widget.receiverId, // Assume it's from the receiver
            'receiverId': widget.currentUserId, // Assume it's to the sender
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

      // Ensure we have sender and receiver IDs
      final senderId = message['senderId'] ?? '';
      final receiverId = message['receiverId'] ?? '';

      print('Message senderId: $senderId, receiverId: $receiverId');
      print(
        'Current chat: currentUserId: ${widget.currentUserId}, receiverId: ${widget.receiverId}',
      );

      // Check if this message is for the current chat
      bool isForCurrentChat = false;

      // Check if the message is between the current sender and receiver
      if ((senderId == widget.receiverId &&
              receiverId == widget.currentUserId) ||
          (senderId == widget.currentUserId &&
              receiverId == widget.receiverId)) {
        isForCurrentChat = true;
        print('Message is for current chat');
      } else {
        print('Message is NOT for current chat, ignoring');
        print('Sender ID match: ${senderId == widget.receiverId}');
        print('Receiver ID match: ${receiverId == widget.currentUserId}');
        print('Reverse sender match: ${senderId == widget.currentUserId}');
        print('Reverse receiver match: ${receiverId == widget.receiverId}');
        print('========== END HANDLING INCOMING MESSAGE (IGNORED) ==========');
        return;
      }

      // Check for content
      final content = message['content'] ?? message['message'] ?? '';
      if (content.isEmpty) {
        print('Message has no content, ignoring');
        print(
          '========== END HANDLING INCOMING MESSAGE (NO CONTENT) ==========',
        );
        return;
      }
      print('Message content: $content');

      // Ensure the message has an ID to prevent duplicates
      String messageId;
      if (message.containsKey('_id')) {
        messageId = message['_id'].toString();
      } else if (message.containsKey('clientId')) {
        messageId = message['clientId'].toString();
      } else {
        // Generate a consistent ID based on content and sender
        messageId =
            '${message['senderId'] ?? ''}_${message['content'] ?? message['message'] ?? ''}_${message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch}';
        message['_id'] = messageId;
      }
      print('Using message ID: $messageId');

      // Check if we've already processed this message by ID
      if (_processedMessageIds.contains(messageId)) {
        print('Message with ID $messageId already processed, ignoring');
        print(
          '========== END HANDLING INCOMING MESSAGE (DUPLICATE ID) ==========',
        );
        return;
      }

      // Also check for duplicates based on content and timestamp
      // This helps catch messages that might have different IDs but are actually the same
      final timestamp = message['timestamp'] ?? message['createdAt'] ?? '';
      bool isDuplicate = false;

      for (final existingMessage in _messages) {
        final existingContent =
            existingMessage['content'] ?? existingMessage['message'] ?? '';
        final existingTimestamp =
            existingMessage['timestamp'] ?? existingMessage['createdAt'] ?? '';
        final existingSender = existingMessage['senderId'] ?? '';

        // If content, sender and timestamp are very close, it's likely a duplicate
        if (existingContent == content &&
            existingSender == senderId &&
            _isTimestampClose(
              existingTimestamp.toString(),
              timestamp.toString(),
            )) {
          isDuplicate = true;
          print('Found duplicate message based on content and timestamp');
          print('Existing message: $existingMessage');
          print('New message: $message');
          break;
        }
      }

      if (isDuplicate) {
        print(
          '========== END HANDLING INCOMING MESSAGE (DUPLICATE CONTENT) ==========',
        );
        return;
      }

      // Add to processed IDs to prevent duplicates
      _processedMessageIds.add(messageId);
      print('Added message ID to processed list: $messageId');

      // Ensure message has all required fields and preserve audio duration
      final processedMessage = {
        ...message,
        'timestamp': message['timestamp'] ?? DateTime.now().toIso8601String(),
        'messageType': message['messageType'] ?? 'text',
        'audioDuration':
            message['audioDuration'] ?? 0, // Explicitly preserve audio duration
      };

      // Add the message to the UI
      setState(() {
        _messages.add(processedMessage);
        print(
          'Added message to UI: ${processedMessage['content'] ?? processedMessage['message']}',
        );

        // If this was a message we were sending, mark sending as complete
        if (senderId == widget.currentUserId) {
          _isSending = false;
        }
      });

      // Scroll to the bottom
      _scrollToBottom();
      print('Scrolled to bottom after adding message');

      print('========== END HANDLING INCOMING MESSAGE ==========');
    } catch (e) {
      print('Error handling incoming message: $e');
      print(e.toString());
      print('========== END HANDLING INCOMING MESSAGE (ERROR) ==========');
    }
  }

  // Helper method to check if two timestamps are close (within 2 seconds)
  bool _isTimestampClose(String timestamp1, String timestamp2) {
    try {
      final date1 = DateTime.parse(timestamp1);
      final date2 = DateTime.parse(timestamp2);

      // Calculate the difference in seconds
      final difference = date1.difference(date2).inSeconds.abs();

      // If the timestamps are within 2 seconds, consider them close
      return difference <= 2;
    } catch (e) {
      print('Error comparing timestamps: $e');
      return false;
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final messages = await widget.chatService.getMessages(
        widget.receiverId,
        widget.token,
      );

      if (mounted) {
        setState(() {
          // Process each message and add to the processed IDs set
          _messages = [];
          _processedMessageIds.clear();

          // Find the newest message timestamp
          String? newestTimestamp;
          for (final message in messages) {
            final messageId =
                message['_id'] ??
                '${message['senderId']}_${message['content'] ?? message['message']}_${message['timestamp'] ?? message['createdAt']}';
            _processedMessageIds.add(messageId);
            _messages.add(message);

            // Track the newest timestamp
            final timestamp = message['timestamp'] ?? message['createdAt'];
            if (timestamp != null) {
              if (newestTimestamp == null ||
                  timestamp.toString().compareTo(newestTimestamp) > 0) {
                newestTimestamp = timestamp.toString();
              }
            }
          }

          // Initialize the last message timestamp
          _lastMessageTimestamp = newestTimestamp;
          if (_lastMessageTimestamp != null) {
            print('Initialized last message timestamp: $_lastMessageTimestamp');
          }

          _isLoading = false;
        });

        if (_messages.isNotEmpty) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _startSocketCheck() {
    // Check both sockets every 5 seconds
    Timer.periodic(Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      _checkSocketConnections();
    });
  }

  void _checkSocketConnections() {
    // Check direct socket
    if (!socket.connected) {
      print('Direct socket disconnected, reconnecting...');
      socket.connect();
    }

    // Check ChatService socket
    if (widget.chatService.socket == null ||
        !widget.chatService.socket!.connected) {
      print('ChatService socket disconnected, reconnecting...');
      widget.chatService.connectSocket(widget.currentUserId);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      print('Message content is empty, not sending');
      return;
    }

    final content = _messageController.text.trim();
    print('Sending message: $content');

    // Create a unique client ID for this message to prevent duplicates
    final clientId =
        '${widget.currentUserId}_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
    print('Generated clientId: $clientId');

    // Create a message object
    final message = {
      'senderId': widget.currentUserId,
      'receiverId': widget.receiverId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'clientId': clientId,
      '_id': clientId, // Use the same ID locally to help with deduplication
    };

    // Add the message to the UI immediately
    setState(() {
      _messages.add(message);
      _isSending = true;
      _messageController.clear();
    });

    // Scroll to the bottom
    _scrollToBottom();

    // Check if socket is connected
    bool socketConnected = false;
    try {
      socketConnected = widget.chatService.isSocketConnected();
      print('Socket connected: $socketConnected');
    } catch (e) {
      print('Error checking socket connection: $e');
    }

    // Try to send via socket first
    if (socketConnected) {
      try {
        print('Attempting to send message via socket');
        // Send the message through the socket
        await widget.chatService.sendMessage(
          widget.receiverId,
          content,
          widget.token,
          widget.currentUserId,
          clientId, // Pass the clientId to prevent duplicates
        );

        print('Message sent via socket successfully');
        setState(() {
          _isSending = false;
        });
        return; // If socket send succeeds, don't try HTTP
      } catch (e) {
        print('Error sending message via socket: $e');
        // Continue to HTTP fallback
      }
    }

    // Fallback to HTTP if socket fails or is not connected
    try {
      print('Attempting to send message via HTTP');

      // Make a direct HTTP call to send the message
      final response = await http.post(
        Uri.parse(
          'https://farmcare-backend-new.onrender.com/api/v1/message/send',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: json.encode({
          'receiverId': widget.receiverId,
          'content': content,
          'clientId': clientId, // Include clientId to prevent duplicates
        }),
      );

      print('HTTP response status: ${response.statusCode}');
      print('HTTP response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Message sent via HTTP successfully');

        // Try to parse the response to get the server's message ID
        try {
          final responseData = json.decode(response.body);
          if (responseData.containsKey('_id')) {
            // Update our local message with the server's ID
            for (int i = 0; i < _messages.length; i++) {
              if (_messages[i]['clientId'] == clientId) {
                setState(() {
                  _messages[i]['_id'] = responseData['_id'];
                  _processedMessageIds.add(
                    responseData['_id'],
                  ); // Add to processed IDs
                });
                break;
              }
            }
          }
        } catch (e) {
          print('Error parsing HTTP response: $e');
        }

        // Also send a notification to ensure the receiver gets it
        try {
          await http.post(
            Uri.parse(
              'https://farmcare-backend-new.onrender.com/api/v1/notification',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.token}',
            },
            body: json.encode({
              'receiverId': widget.receiverId,
              'type': 'message',
              'content': content,
              'senderId': widget.currentUserId,
              'clientId': clientId, // Include clientId to prevent duplicates
            }),
          );
          print('Notification sent successfully');
        } catch (e) {
          print('Error sending notification: $e');
        }
      } else {
        print(
          'Failed to send message via HTTP: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      print('Error sending message via HTTP: $e');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _pollForNewMessages() async {
    try {
      print('Polling for new messages...');
      final messages = await widget.chatService.getMessages(
        widget.receiverId,
        widget.token,
      );

      if (!mounted) return;

      // Find the newest message timestamp
      String? newestTimestamp;
      for (final message in messages) {
        final timestamp = message['timestamp'] ?? message['createdAt'];
        if (timestamp != null) {
          if (newestTimestamp == null ||
              timestamp.toString().compareTo(newestTimestamp) > 0) {
            newestTimestamp = timestamp.toString();
          }
        }
      }

      // If we have a new timestamp, process new messages
      if (newestTimestamp != null &&
          (_lastMessageTimestamp == null ||
              newestTimestamp.compareTo(_lastMessageTimestamp!) > 0)) {
        print('Found newer messages in poll, processing...');

        // Process only new messages
        for (final message in messages) {
          final timestamp = message['timestamp'] ?? message['createdAt'];
          if (timestamp != null &&
              _lastMessageTimestamp != null &&
              timestamp.toString().compareTo(_lastMessageTimestamp!) > 0) {
            _handleIncomingMessage(message);
          }
        }

        // Update the last timestamp
        _lastMessageTimestamp = newestTimestamp;
      } else {
        print('No new messages found in poll');
      }
    } catch (e) {
      print('Error polling for messages: $e');
    }
  }

  bool isUserOnline() {
    return _onlineUsers.contains(widget.receiverId);
  }

  // Update _launchDialer method:
  Future<void> _launchDialer(String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanedNumber.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid phone number')));
      return;
    }

    final Uri phoneLaunchUri = Uri(scheme: 'tel', path: cleanedNumber);

    if (await Permission.phone.request().isGranted) {
      if (await canLaunchUrl(phoneLaunchUri)) {
        await launchUrl(phoneLaunchUri);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch dialer')));
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Phone permission denied')));
    }
  }

  // Add image picker method
  Future<void> _pickAndSendImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _isUploadingImage = true);

        final file = File(image.path);
        final size = await file.length();

        // Check file size (5MB limit)
        if (size > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image size should be less than 5MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Check file type
        final mimeType = lookupMimeType(image.path);
        if (!mimeType!.startsWith('image/')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an image file'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Send image message
        final response = await widget.chatService.sendImageMessage(
          receiverId: widget.receiverId,
          imageFile: file,
        );

        if (!mounted) return;

        if (response['success'] == true) {
          final message = response['data'];
          _handleIncomingMessage(message);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send image: ${response['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking/sending image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _initAudioRecorder() async {
    _audioRecorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }

    // Initialize recorder
    await _audioRecorder!.openRecorder();
    await _audioPlayer!.openPlayer();
  }

  Future<void> _startRecording() async {
    try {
      // Create a temporary file for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath =
          '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.aac';

      // Start recording
      await _audioRecorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
        sampleRate: 44100,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start timer to update duration
      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += Duration(seconds: 1);
        });
      });
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start recording')));
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder!.stopRecorder();
      _recordingTimer?.cancel();

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        if (await file.exists()) {
          // Send the voice message
          final response = await widget.chatService.sendVoiceMessage(
            receiverId: widget.receiverId,
            audioFile: file,
            duration: _recordingDuration,
          );

          if (response['success'] == true) {
            final message = response['data'];
            _handleIncomingMessage(message);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send voice message')),
            );
          }
        }
      }

      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to stop recording')));
    }
  }

  Future<void> _playVoiceMessage(String audioUrl, String messageId) async {
    try {
      // If a message is already playing, stop it
      if (_currentlyPlayingMessageId != null) {
        await _audioPlayer!.stopPlayer();
      }

      await _audioPlayer!.startPlayer(
        fromURI: audioUrl,
        codec: Codec.aacADTS,
        sampleRate: 44100,
      );

      setState(() => _currentlyPlayingMessageId = messageId);

      // Listen for player completion
      _audioPlayer!.setSubscriptionDuration(Duration(milliseconds: 100));
      _audioPlayer!.onProgress!.listen((event) {
        if (event.position >= event.duration) {
          setState(() => _currentlyPlayingMessageId = null);
        }
      });
    } catch (e) {
      print('Error playing voice message: $e');
      setState(() => _currentlyPlayingMessageId = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to play voice message')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade800,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.receiverName,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  _isConnected
                      ? AppLocalizations.translate('online', currentLanguage)
                      : 'Socket Offline',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () async {
              if (widget.receiverPhone.isNotEmpty) {
                await _launchDialer(widget.receiverPhone);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('No phone number available')),
                );
              }
            },
            icon: Icon(Icons.phone),
          ),
          if (!_isConnected)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                socket.connect();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reconnecting socket...')),
                );
              },
            ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(color: Colors.green.shade50),
        child: Column(
          children: [
            Expanded(child: _buildMessageList(currentLanguage)),
            _buildMessageInput(currentLanguage),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(String currentLanguage) {
    if (_isLoading && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade800),
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.translate('loading', currentLanguage),
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(_error!),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadMessages,
              icon: Icon(Icons.refresh),
              label: Text(AppLocalizations.translate('retry', currentLanguage)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.translate('noMessages', currentLanguage),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Send a message to start the conversation',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    // Group messages by date
    final groupedMessages = <String, List<Map<String, dynamic>>>{};

    for (final message in _messages) {
      try {
        final dateTimeStr = message['timestamp'] ?? message['createdAt'] ?? '';
        DateTime dateTime;

        try {
          dateTime = DateTime.parse(dateTimeStr.toString());
        } catch (e) {
          // Fallback if parsing fails
          print('Error parsing message date: $dateTimeStr, error: $e');
          dateTime = DateTime.now();
        }

        // Use only the date part for grouping
        final date = '${dateTime.year}-${dateTime.month}-${dateTime.day}';

        if (!groupedMessages.containsKey(date)) {
          groupedMessages[date] = [];
        }

        groupedMessages[date]!.add(message);
      } catch (e) {
        print('Error processing message: $message, error: $e');
        // Skip this message if there's an error
      }
    }

    // Sort dates
    final sortedDates = groupedMessages.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final messages = groupedMessages[date]!;

        return Column(
          children: [
            _buildDateDivider(date),
            ...messages.map((message) => _buildMessageBubble(message)),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(String date) {
    final now = DateTime.now();
    DateTime messageDate;

    try {
      // Ensure proper date format with padding
      final parts = date.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        messageDate = DateTime(year, month, day);
      } else {
        // Fallback if date format is unexpected
        messageDate = now;
      }
    } catch (e) {
      print('Error parsing date: $date, error: $e');
      // Fallback to current date if parsing fails
      messageDate = now;
    }

    String dateText;
    if (messageDate.year == now.year &&
        messageDate.month == now.month &&
        messageDate.day == now.day) {
      dateText = 'Today';
    } else if (messageDate.year == now.year &&
        messageDate.month == now.month &&
        messageDate.day == now.day - 1) {
      dateText = 'Yesterday';
    } else {
      dateText =
          '${messageDate.day.toString().padLeft(2, '0')}/${messageDate.month.toString().padLeft(2, '0')}/${messageDate.year}';
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMe = message['senderId'] == widget.currentUserId;
    final content = message['content']?.toString() ?? '';
    final messageId = message['_id'] ?? message['clientId'] ?? '';

    // Check for message type and content
    bool isImage = message['messageType'] == 'image';
    bool isVoice = message['messageType'] == 'voice';

    // If messageType is not explicitly set, check the content
    if (!isImage && !isVoice && content.contains('cloudinary.com')) {
      final lowerContent = content.toLowerCase();
      // Check for image extensions
      if (lowerContent.contains('/image/') ||
          lowerContent.endsWith('.jpg') ||
          lowerContent.endsWith('.jpeg') ||
          lowerContent.endsWith('.png') ||
          lowerContent.endsWith('.gif')) {
        isImage = true;
      }
      // Check for audio extensions
      else if (lowerContent.endsWith('.mp3') ||
          lowerContent.endsWith('.aac') ||
          lowerContent.endsWith('.wav') ||
          lowerContent.endsWith('.m4a')) {
        isVoice = true;
      }
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage)
              GestureDetector(
                onTap: () {
                  // Show full-screen image view
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: Stack(
                        children: [
                          InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(
                              content,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.error),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    content,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 200,
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[300],
                        child: Icon(Icons.error),
                      );
                    },
                  ),
                ),
              )
            else if (isVoice)
              GestureDetector(
                onTap: () => _playVoiceMessage(content, messageId),
                child: Container(
                  width: 200,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentlyPlayingMessageId == messageId
                            ? Icons.stop
                            : Icons.play_arrow,
                        color: Colors.green.shade800,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Message',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${message['audioDuration'] ?? 0}s',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                content,
                style: TextStyle(color: Colors.black87, fontSize: 16),
              ),
            SizedBox(height: 4),
            Text(
              _formatTimestamp(message['timestamp']),
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final dateTime = DateTime.parse(timestamp.toString());
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('Error formatting timestamp: $timestamp, error: $e');
      // Return current time as fallback
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageInput(String currentLanguage) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: _isUploadingImage ? null : _pickAndSendImage,
            tooltip: 'Send Image',
          ),
          if (_isRecording)
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Recording... ${_recordingDuration.inSeconds}s',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: AppLocalizations.translate(
                    'typeMessage',
                    currentLanguage,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          SizedBox(width: 8),
          if (_isRecording)
            IconButton(
              icon: Icon(Icons.stop, color: Colors.red),
              onPressed: _stopRecording,
            )
          else
            IconButton(icon: Icon(Icons.mic), onPressed: _startRecording),
          SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade800,
              shape: BoxShape.circle,
            ),
            child: _isSending
                ? Container(
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    widget.chatService.disconnectSocket();
    socket.disconnect();
    socket.dispose();
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
    _recordingTimer?.cancel();
    super.dispose();
  }
}
