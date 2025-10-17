import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final File? imageFile;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.imageFile,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  late GenerativeModel _model;
  late GenerativeModel _visionModel;
  late ChatSession _chatSession;

  // Text to speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  String? _currentlySpeakingMessageText;

  // Enhanced color scheme - Light theme with dark text
  final Color _darkGreen = const Color(
    0xFF1B5E20,
  ); // Even darker for text/icons
  final Color _lightGreen = const Color(0xFFE8F5E9); // Very light green
  final Color _earthBrown = const Color(0xFF4E342E); // Darker brown for icons
  final Color _creamBackground = const Color(
    0xFFFAFAFA,
  ); // Light gray background
  final Color _messageUserBubble = const Color(
    0xFFE8F5E9,
  ); // Light green for user
  final Color _messageAIBubble = const Color(0xFFFFFFFF); // White for AI
  final Color _shadowColor = Colors.black12;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  double _confidence = 1.0;
  String _selectedLanguage = 'ta-IN';
  String _displayLanguage = 'தமிழ்';
  String _ttsLanguage = 'ta-IN';

  Offset _micPosition = const Offset(20, 100); // Changed position to top corner

  final Map<String, String> _languageMap = {
    'தமிழ்': 'ta-IN',
    'മലയാളം': 'ml-IN',
    'हिन्दी': 'hi-IN',
    'English': 'en-US',
  };

  // TTS language mapping
  final Map<String, String> _ttsLanguageMap = {
    'ta-IN': 'ta-IN',
    'ml-IN': 'ml-IN',
    'hi-IN': 'hi-IN',
    'en-US': 'en-US',
  };

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeGemini();
    _initializeTts();
    // Add welcome message
    _addWelcomeMessage();
  }

  void _initializeTts() async {
    await _flutterTts.setLanguage(
      _ttsLanguageMap[_selectedLanguage] ?? 'en-US',
    );

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
        _currentlySpeakingMessageText = null;
      });
    });

    _flutterTts.setErrorHandler((error) {
      setState(() {
        _isSpeaking = false;
        _currentlySpeakingMessageText = null;
      });
    });
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text:
              "👋 Welcome to FarmHelper! Ask me anything about crops, weather, farming techniques, or upload a photo of your plants for analysis.",
          isUser: false,
        ),
      );
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _initializeGemini() {
    const apiKey = 'AIzaSyDu2g3aU4671bDMCWRX_8fSw_PyFxfcazQ';

    _model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
    _visionModel = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);
    _chatSession = _model.startChat();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speakText(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      if (_currentlySpeakingMessageText == text) {
        setState(() {
          _isSpeaking = false;
          _currentlySpeakingMessageText = null;
        });
        return;
      }
    }

    setState(() {
      _isSpeaking = true;
      _currentlySpeakingMessageText = text;
    });

    await _flutterTts.setLanguage(
      _ttsLanguageMap[_selectedLanguage] ?? 'en-US',
    );
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty && _selectedImage == null) return;
    _textController.clear();

    // Add user message
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, imageFile: _selectedImage),
      );
      _isLoading = true;
    });

    _scrollToBottom();

    String response = '';
    try {
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        final content = [
          Content.multi([TextPart(text), DataPart('image/jpeg', bytes)]),
        ];
        final result = await _visionModel.generateContent(content);
        response = result.text ?? 'No response generated';
        setState(() => _selectedImage = null);
      } else {
        final result = await _chatSession.sendMessage(Content.text(text));
        response = result.text ?? 'No response generated';
      }
    } catch (e) {
      response = 'Sorry, I encountered an error. Please try again.';
    }

    // Add AI response
    setState(() {
      _messages.add(ChatMessage(text: response, isUser: false));
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF1B5E20),
                ),
                title: const Text(
                  'Photo Gallery',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF1B5E20)),
                title: const Text(
                  'Camera',
                  style: TextStyle(color: Colors.black87),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source != null) {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) setState(() => _selectedImage = File(image.path));
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('STATUS: $val'),
        onError: (val) => print('ERROR: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        await _speech.listen(
          localeId: _selectedLanguage,
          onResult: (val) {
            setState(() {
              _textController.text = val.recognizedWords;
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
              if (val.hasConfidenceRating && val.confidence > 0) {
                _confidence = val.confidence;
              }
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _showLanguagePopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.language, color: _darkGreen),
            const SizedBox(width: 10),
            const Text(
              'Select Language',
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _languageMap.entries.map((entry) {
            return ListTile(
              title: Text(
                entry.key,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: _selectedLanguage == entry.value
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              leading: Radio<String>(
                value: entry.value,
                groupValue: _selectedLanguage,
                activeColor: _darkGreen,
                onChanged: (String? value) {
                  if (value != null) {
                    Navigator.pop(context);
                    setState(() {
                      _selectedLanguage = value;
                      _displayLanguage = entry.key;
                      _ttsLanguage = _ttsLanguageMap[value] ?? 'en-US';
                      _flutterTts.setLanguage(_ttsLanguage);
                    });
                    _listen();
                  }
                },
              ),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedLanguage = entry.value;
                  _displayLanguage = entry.key;
                  _ttsLanguage = _ttsLanguageMap[entry.value] ?? 'en-US';
                  _flutterTts.setLanguage(_ttsLanguage);
                });
                _listen();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: _darkGreen)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 6.0,
            color: _shadowColor,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: Icon(
                Icons.add_photo_alternate,
                color: _earthBrown,
                size: 24,
              ),
              onPressed: _pickImage,
              tooltip: 'Add Image',
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _darkGreen),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Ask about crops, weather, or farming...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  ),
                  style: const TextStyle(color: Colors.black87),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _isLoading ? null : _handleSubmit,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: _isLoading
                  ? null
                  : () => _handleSubmit(_textController.text),
              backgroundColor: _darkGreen,
              elevation: 2,
              mini: true,
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildMessage(ChatMessage message, bool showTimestamp) {
    final bool isCurrentlySpeaking =
        _currentlySpeakingMessageText == message.text;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!message.isUser)
                Hero(
                  tag: 'assistant_avatar',
                  child: Container(
                    margin: const EdgeInsets.only(right: 8.0),
                    child: CircleAvatar(
                      backgroundColor: _lightGreen,
                      child: Icon(Icons.eco, color: _darkGreen, size: 18),
                    ),
                  ),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? _messageUserBubble
                        : _messageAIBubble,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 2),
                        blurRadius: 4.0,
                        color: _shadowColor,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imageFile != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          height: 200,
                          width: double.infinity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              message.imageFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Text(
                        message.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: message.isUser
                              ? Colors.black87
                              : Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: GestureDetector(
                          onTap: () => _speakText(message.text),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isCurrentlySpeaking
                                  ? _darkGreen.withOpacity(0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCurrentlySpeaking
                                  ? Icons.stop
                                  : Icons.volume_up,
                              size: 18,
                              color: _darkGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (message.isUser)
                Container(
                  margin: const EdgeInsets.only(left: 8.0),
                  child: CircleAvatar(
                    backgroundColor: _lightGreen,
                    child: Icon(Icons.person, color: _darkGreen, size: 18),
                  ),
                ),
            ],
          ),
          if (showTimestamp)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Text(
              '${date.day}/${date.month}/${date.year}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  List<Widget> _buildMessageList() {
    final List<Widget> widgets = [];
    DateTime? lastDate;

    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final bool showTimestamp =
          i == _messages.length - 1 ||
          _messages[i + 1].isUser != message.isUser ||
          _messages[i + 1].timestamp.difference(message.timestamp).inMinutes >
              2;

      // Check if we need a date separator
      final messageDate = DateTime(
        message.timestamp.year,
        message.timestamp.month,
        message.timestamp.day,
      );

      if (lastDate == null || messageDate != lastDate) {
        widgets.add(_buildDateSeparator(messageDate));
        lastDate = messageDate;
      }

      widgets.add(_buildMessage(message, showTimestamp));
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, size: 24, color: Colors.white),
            SizedBox(width: 10),
            Text(
              'FarmHelper',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade300,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {
              setState(() {
                _messages.add(
                  ChatMessage(
                    text:
                        "How can I help you with farming today? You can ask about:\n\n• Plant diseases and pest identification\n• Crop recommendations\n• Weather guidance\n• Sustainable farming practices\n• Local farming techniques",
                    isUser: false,
                  ),
                );
              });
              _scrollToBottom();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: const DecorationImage(
            image: NetworkImage(
              'https://www.transparenttextures.com/patterns/cream-paper.png',
            ),
            repeat: ImageRepeat.repeat,
            opacity: 0.15,
          ),
          color: _creamBackground,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.nature_people,
                                size: 80,
                                color: _darkGreen.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Welcome to FarmHelper',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _darkGreen,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ask anything about farming',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(12.0),
                          reverse: true,
                          controller: _scrollController,
                          children: _buildMessageList().reversed.toList(),
                        ),
                ),
                if (_selectedImage != null)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: _darkGreen, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            height: 100,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 20,
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  setState(() => _selectedImage = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isLoading)
                  Container(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: _lightGreen,
                      valueColor: AlwaysStoppedAnimation<Color>(_darkGreen),
                    ),
                  ),
                _buildTextComposer(),
              ],
            ),
            Positioned(
              left: _micPosition.dx,
              top: _micPosition.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _micPosition += details.delta;
                  });
                },
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _darkGreen, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.white : _darkGreen,
                          ),
                          onPressed: _listen,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _lightGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _displayLanguage,
                            style: TextStyle(
                              color: _darkGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: _isListening ? Colors.white : _darkGreen,
                          ),
                          onPressed: _showLanguagePopup,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
