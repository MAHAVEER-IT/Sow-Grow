import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sow_and_grow/Blog/UI/Blog_UI.dart';
import 'package:sow_and_grow/Blog/Service/translation_service.dart';
import 'package:sow_and_grow/Blog/Widgets/comment_dialog.dart';
import 'package:sow_and_grow/Blog/Widgets/language_widgets.dart';
import 'package:sow_and_grow/Blog/utility/language_constants.dart';
import 'package:sow_and_grow/utils/Language/app_localizations.dart';
import 'package:sow_and_grow/utils/Language/language_provider.dart';

import '../Service/Blog_services.dart';

class PostDetailPage extends StatefulWidget {
  final BlogPost post;

  const PostDetailPage({Key? key, required this.post}) : super(key: key);

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final BlogService _blogService = BlogService();
  late BlogPost post;
  String? userId;
  bool _translating = false;
  String _currentLanguage = 'en'; // Default to English
  bool _isSpeaking = false;
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    post = widget.post;
    _loadUserId();
    _initTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((error) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<void> _speak() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
      return;
    }

    // Set the language for TTS based on current language selection
    await _flutterTts.setLanguage(
      BlogLanguageConstants.ttsLanguageCodes[_currentLanguage] ?? 'en-US',
    );

    // Prepare the text to be read (title + content)
    String textToRead = '${post.title}. ${post.content}';

    setState(() {
      _isSpeaking = true;
    });

    await _flutterTts.speak(textToRead);
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('userId');
    });
  }

  Future<void> _handleLike() async {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to like posts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      setState(() {
        if (post.likeUsers.contains(userId)) {
          post.likeUsers.remove(userId);
          post.likeCount--;
        } else {
          post.likeUsers.add(userId!);
          post.likeCount++;
        }
      });

      await _blogService.updateLike(post.postId, userId!);
    } catch (e) {
      // Revert on error
      setState(() {
        if (post.likeUsers.contains(userId)) {
          post.likeUsers.remove(userId);
          post.likeCount--;
        } else {
          post.likeUsers.add(userId!);
          post.likeCount++;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update like: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Function to translate post content
  Future<void> _translatePost(String langCode) async {
    if (langCode == 'en') {
      // Reset post to original language
      setState(() {
        post.title = post.originalTitle;
        post.content = post.originalContent;
        _currentLanguage = langCode;
      });
      return;
    }

    setState(() {
      _translating = true;
    });

    try {
      // Translate title and content using TranslationService
      String translatedTitle = await TranslationService.translateText(
        post.originalTitle,
        langCode,
      );

      String translatedContent = await TranslationService.translateText(
        post.originalContent,
        langCode,
      );

      // Update post if translation was successful
      if (mounted) {
        setState(() {
          post.title = translatedTitle;
          post.content = translatedContent;
          _currentLanguage = langCode;
        });
      }
    } catch (e) {
      print('Error during translation: $e');
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed. Please try again later.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _translating = false;
        });
      }
    }
  }

  // Show language selection dialog
  void _showLanguageDialog() {
    LanguageSelectionDialog.show(
      context,
      currentLanguage: _currentLanguage,
      onLanguageSelected: (String langCode) {
        _translatePost(langCode);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final currentLanguage = languageProvider.currentLanguage;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.green.shade300,
        title: Text(
          AppLocalizations.translate('AgriTalks', currentLanguage),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: _translating
          ? TranslationLoadingWidget()
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.images.isNotEmpty)
                    Container(
                      height: 250,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: 'post-image-${post.postId}',
                            child: Image.network(
                              post.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.error_outline,
                                    size: 50,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),
                          // Semi-transparent gradient at the bottom for text visibility
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Post title overlay on the image
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            child: Text(
                              post.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    blurRadius: 2,
                                    offset: Offset(1, 1),
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author info card
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.green.shade100,
                                  backgroundImage: NetworkImage(
                                    "https://ui-avatars.com/api/?name=${Uri.encodeComponent(post.authorName.replaceAll(' ', '+'))}&background=4CAF50&color=fff",
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.authorName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            post.createdAt.toString(),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Only show title here if there's no image
                        if (post.images.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                              post.title,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),

                        // Post content
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            post.content,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.6,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),

                        // Text-to-Speech button
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: InkWell(
                            onTap: _speak,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isSpeaking
                                        ? Icons.stop_circle
                                        : Icons.volume_up,
                                    color: Colors.green.shade600,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isSpeaking
                                        ? 'Stop Reading'
                                        : 'Listen to Post',
                                    style: TextStyle(
                                      color: Colors.green.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Interaction bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Like button
                              InkWell(
                                onTap: _handleLike,
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        post.likeUsers.contains(userId)
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: post.likeUsers.contains(userId)
                                            ? Colors.red
                                            : Colors.grey[700],
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${post.likeCount}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Comment button
                              InkWell(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) =>
                                        DraggableScrollableSheet(
                                          initialChildSize: 0.7,
                                          minChildSize: 0.5,
                                          maxChildSize: 0.95,
                                          builder: (_, controller) =>
                                              CommentBottomSheet(
                                                postId: post.postId,
                                                onCommentAdded: () {
                                                  setState(() {
                                                    post.commentCount++;
                                                  });
                                                },
                                              ),
                                        ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.comment_outlined,
                                        color: Colors.grey[700],
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${post.commentCount}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showLanguageDialog,
        tooltip: 'Change Language',
        backgroundColor: Colors.green.shade800,
        elevation: 4,
        child: const Icon(Icons.language, color: Colors.white),
      ),
    );
  }
}
