import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../Service/create_blog_services.dart';

class CreateBlogPage extends StatefulWidget {
  const CreateBlogPage({Key? key}) : super(key: key);

  @override
  State<CreateBlogPage> createState() => _CreateBlogPageState();
}

class _CreateBlogPageState extends State<CreateBlogPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  String? _imageError;

  final CreateBlogService _blogService = CreateBlogService();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _selectedLanguage = 'ta-IN';

  final Map<String, String> _languageMap = {
    'தமிழ்': 'ta-IN',
    'മലയാളം': 'ml-IN',
    'हिन्दी': 'hi-IN',
    'English': 'en-US',
  };

  // Define our light color palette with dark text
  final Color _backgroundLight = Colors.green.shade50;
  final Color _backgroundMedium = Colors.green.shade100;
  final Color _cardBackground = Colors.white;
  final Color _darkText = Colors.green.shade800;
  final Color _mediumText = Colors.green.shade700;
  final Color _lightText = Colors.grey.shade600;
  final Color _accentColor = Colors.green.shade400;
  final Color _borderColor = Colors.green.shade200;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _imageError = null);

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final file = File(image.path);
        final size = await file.length();

        if (size > 5 * 1024 * 1024) {
          setState(() {
            _imageError = 'Image size should be less than 5MB';
          });
          return;
        }

        final mimeType = lookupMimeType(image.path);
        if (!mimeType!.startsWith('image/')) {
          setState(() {
            _imageError = 'Please select an image file';
          });
          return;
        }

        setState(() {
          _imageFile = file;
          _imageError = null;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      setState(() {
        _imageError = 'Error picking image: $e';
      });
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
              _contentController.text = val.recognizedWords;
              _contentController.selection = TextSelection.fromPosition(
                TextPosition(offset: _contentController.text.length),
              );
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _imageError = null;
    });

    try {
      final response = await _blogService.createBlog(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageFile: _imageFile,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post created successfully'),
            backgroundColor: Colors.green.shade600,
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception(response['message'] ?? 'Failed to create blog');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Share AgriTalk",
          style: TextStyle(
            color: _darkText,
            fontWeight: FontWeight.bold,
            fontSize: 26,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: _darkText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_backgroundLight, _backgroundMedium, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/cubes.png',
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                physics: BouncingScrollPhysics(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Share Your Knowledge",
                        style: TextStyle(
                          color: _mediumText,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      // Cover Image Card
                      Card(
                        elevation: 4,
                        color: _cardBackground,
                        shadowColor: Colors.green.shade200.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: _isLoading ? null : _pickImage,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                height: 220,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: _imageFile == null
                                      ? LinearGradient(
                                          colors: [
                                            _backgroundLight,
                                            _backgroundMedium,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  border: _imageFile == null
                                      ? Border.all(
                                          color: _borderColor,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: _imageFile != null
                                    ? Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            child: Image.file(
                                              _imageFile!,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                            ),
                                          ),
                                          // Overlay gradient for better text visibility
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.4),
                                                ],
                                                stops: [0.7, 1.0],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 16,
                                            left: 16,
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.edit,
                                                    size: 16,
                                                    color: _accentColor,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Change Image',
                                                    style: TextStyle(
                                                      color: _darkText,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: InkWell(
                                              onTap: () => setState(() {
                                                _imageFile = null;
                                                _imageError = null;
                                              }),
                                              child: Container(
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.9),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 20,
                                                  color: _accentColor,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _backgroundMedium,
                                            ),
                                            child: Icon(
                                              Icons.add_photo_alternate_rounded,
                                              size: 50,
                                              color: _accentColor,
                                            ),
                                          ),
                                          SizedBox(height: 12),
                                          Text(
                                            'Add Cover Image',
                                            style: TextStyle(
                                              color: _darkText,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            'Make your knowledge stand out',
                                            style: TextStyle(
                                              color: _mediumText,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            if (_imageError != null)
                              Padding(
                                padding: EdgeInsets.all(12),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _imageError!,
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24),
                      // Title Card
                      Card(
                        elevation: 3,
                        color: _cardBackground,
                        shadowColor: Colors.green.shade200.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 6,
                          ),
                          child: TextFormField(
                            controller: _titleController,
                            enabled: !_isLoading,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _darkText,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Title Your AgriTalk',
                              hintStyle: TextStyle(
                                color: _lightText,
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(
                                Icons.title,
                                color: _accentColor,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Please enter a title';
                              }
                              if (value!.length > 100) {
                                return 'Title too long (max 100 characters)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      // Content Card
                      Card(
                        elevation: 3,
                        color: _cardBackground,
                        shadowColor: Colors.green.shade200.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    color: _accentColor,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Write Your AgriTalk',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _darkText,
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 24, color: _borderColor),
                              TextFormField(
                                controller: _contentController,
                                enabled: !_isLoading,
                                maxLines: 10,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.6,
                                  color: _darkText,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Share your thoughts, ideas, and stories here...',
                                  hintStyle: TextStyle(color: _lightText),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                validator: (value) {
                                  if (value?.isEmpty ?? true) {
                                    return 'Please enter some content';
                                  }
                                  if (value!.length < 10) {
                                    return 'Content too short (min 10 characters)';
                                  }
                                  if (value.length > 5000) {
                                    return 'Content too long (max 5000 characters)';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _backgroundLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _borderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: _borderColor,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _languageMap.entries
                                                .firstWhere(
                                                  (e) =>
                                                      e.value ==
                                                      _selectedLanguage,
                                                )
                                                .key,
                                            onChanged: (String? newValue) {
                                              setState(() {
                                                _selectedLanguage =
                                                    _languageMap[newValue!]!;
                                              });
                                            },
                                            icon: Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: _accentColor,
                                            ),
                                            items: _languageMap.keys
                                                .map<DropdownMenuItem<String>>(
                                                  (String lang) =>
                                                      DropdownMenuItem<String>(
                                                        value: lang,
                                                        child: Text(
                                                          lang,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: _darkText,
                                                          ),
                                                        ),
                                                      ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Material(
                                      color: _isListening
                                          ? Colors.green.shade500
                                          : _accentColor,
                                      borderRadius: BorderRadius.circular(12),
                                      elevation: 2,
                                      child: InkWell(
                                        onTap: _listen,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: EdgeInsets.all(12),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _isListening
                                                    ? Icons.mic
                                                    : Icons.mic_none_rounded,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                _isListening
                                                    ? 'Listening...'
                                                    : 'Voice Input',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 32),
                      // Submit Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: Colors.green.shade300.withOpacity(0.5),
                          disabledBackgroundColor: Colors.grey.shade400,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading)
                              Container(
                                width: 24,
                                height: 24,
                                margin: EdgeInsets.only(right: 12),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            Text(
                              _isLoading ? 'Publishing...' : 'Share AgriTalk',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (!_isLoading)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade200.withOpacity(0.5),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              color: _accentColor,
                              strokeWidth: 5,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Sharing your AgriTalk...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _darkText,
                            ),
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
