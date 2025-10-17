import 'dart:async';
import 'package:flutter/material.dart';
import '../Models/comment.dart';
import '../Service/Blog_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final Function onCommentAdded;

  const CommentBottomSheet({
    Key? key,
    required this.postId,
    required this.onCommentAdded,
  }) : super(key: key);

  @override
  _CommentBottomSheetState createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final _commentController = TextEditingController();
  final _blogService = BlogService();
  List<Comment> _comments = [];
  bool _isLoading = false;
  String? _error;
  String? _replyingToId;
  String _replyingToAuthor = '';

  // Lighter green color palette
  final Color primaryGreen = Colors.green.shade400;
  final Color lightGreen = Colors.green.shade200;
  final Color accentGreen = Colors.green.shade400;
  final Color backgroundGreen = Colors.green.shade50;
  final Color midGreen = Colors.green.shade300;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Loading comments for post: ${widget.postId}');

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('Please login to view comments');
      }

      final comments = await _blogService.getComments(widget.postId);

      if (!mounted) return;

      setState(() {
        _comments = comments;
        _isLoading = false;
      });

      print('Successfully loaded ${comments.length} comments');
    } catch (e) {
      print('Error loading comments: $e');
      if (!mounted) return;

      String errorMessage;
      if (e is TimeoutException) {
        errorMessage =
            'Connection timed out. Please check your internet and try again.';
      } else if (e.toString().contains('Not authenticated') ||
          e.toString().contains('Please login')) {
        errorMessage = 'Please login to view comments';
      } else {
        errorMessage = 'Failed to load comments. Please try again.';
      }

      setState(() {
        _isLoading = false;
        _error = errorMessage;
      });

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Error',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(errorMessage),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.white,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (!errorMessage.contains('Please login')) {
                    _loadComments(); // Only retry if not a login error
                  }
                },
                style: TextButton.styleFrom(foregroundColor: primaryGreen),
                child: Text(
                  errorMessage.contains('Please login') ? 'OK' : 'Retry',
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');

      if (userId == null || token == null) {
        throw Exception('Please login to comment');
      }

      print('Adding comment for post: ${widget.postId}');
      final newComment = await _blogService.addComment(
        widget.postId,
        userId,
        comment,
      );

      if (!mounted) return;

      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
        _isLoading = false;
      });

      widget.onCommentAdded();
      print('Comment added successfully');
    } catch (e) {
      print('Error adding comment: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);

      String errorMessage;
      if (e.toString().contains('Not authenticated') ||
          e.toString().contains('Please login')) {
        errorMessage = 'Please login to comment';
      } else {
        errorMessage = 'Failed to add comment. Please try again.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Error',
            style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
          ),
          content: Text(errorMessage),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: primaryGreen),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showReplyField(Comment comment) {
    setState(() {
      _replyingToId = comment.id;
      _replyingToAuthor = comment.authorName;
      _commentController.text = '';
    });
    // Focus the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToAuthor = '';
      _commentController.text = '';
    });
  }

  Future<void> _submitReply() async {
    if (_replyingToId == null) return;

    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final reply = await _blogService.addReply(_replyingToId!, content);

      if (!mounted) return;

      // Find the parent comment and add the reply
      setState(() {
        final parentIndex = _comments.indexWhere((c) => c.id == _replyingToId);
        if (parentIndex != -1) {
          final updatedComment = Comment(
            id: _comments[parentIndex].id,
            postId: _comments[parentIndex].postId,
            userId: _comments[parentIndex].userId,
            authorName: _comments[parentIndex].authorName,
            content: _comments[parentIndex].content,
            createdAt: _comments[parentIndex].createdAt,
            replies: [..._comments[parentIndex].replies, reply],
            replyCount: _comments[parentIndex].replyCount + 1,
            likes: _comments[parentIndex].likes,
            likeCount: _comments[parentIndex].likeCount,
          );
          _comments[parentIndex] = updatedComment;
        }
        _commentController.clear();
        _replyingToId = null;
        _replyingToAuthor = '';
        _isLoading = false;
      });
    } catch (e) {
      print('Error adding reply: $e');
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add reply. Please try again.'),
          backgroundColor: Colors.red,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    }
  }

  Widget _buildReplyBar() {
    if (_replyingToId == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: backgroundGreen,
      child: Row(
        children: [
          Icon(Icons.reply, size: 18, color: midGreen),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to ${_replyingToAuthor}',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close),
            onPressed: _cancelReply,
            color: midGreen,
            iconSize: 20,
            padding: EdgeInsets.all(4),
            constraints: BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: lightGreen, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: midGreen.withOpacity(0.2),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(
                          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(comment.authorName.replaceAll(' ', '+'))}&background=2E7D32&color=fff",
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.authorName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: primaryGreen,
                            ),
                          ),
                          Text(
                            _formatDate(comment.createdAt),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    comment.content,
                    style: TextStyle(fontSize: 15, height: 1.3),
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.reply, size: 16, color: midGreen),
                      label: Text('Reply', style: TextStyle(color: midGreen)),
                      onPressed: () => _showReplyField(comment),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: backgroundGreen.withOpacity(0.6),
                      ),
                    ),
                    SizedBox(width: 8),
                    if (comment.likeCount > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundGreen.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.favorite, size: 14, color: midGreen),
                            SizedBox(width: 4),
                            Text(
                              '${comment.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Replies section
          if (comment.replies.isNotEmpty)
            Container(
              margin: EdgeInsets.only(left: 36),
              padding: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: lightGreen, width: 2)),
              ),
              child: Column(
                children: comment.replies.map((reply) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: midGreen.withOpacity(0.15),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundImage: NetworkImage(
                                  "https://ui-avatars.com/api/?name=${Uri.encodeComponent(reply.authorName.replaceAll(' ', '+'))}&background=66BB6A&color=fff",
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reply.authorName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: midGreen,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(reply.createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            reply.content,
                            style: TextStyle(fontSize: 14, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: backgroundGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: primaryGreen,
                        size: 16,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(color: lightGreen.withOpacity(0.5), thickness: 1),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(accentGreen),
                    ),
                  )
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: primaryGreen,
                          size: 40,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadComments,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: lightGreen,
                          size: 48,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(color: primaryGreen, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) =>
                        _buildCommentItem(_comments[index]),
                  ),
          ),
          _buildReplyBar(),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _replyingToId == null
                          ? 'Add a comment...'
                          : 'Add your reply...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: lightGreen),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: lightGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: accentGreen, width: 2),
                      ),
                      filled: true,
                      fillColor: backgroundGreen.withOpacity(0.3),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryGreen, accentGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_replyingToId != null) {
                              _submitReply();
                            } else {
                              _addComment();
                            }
                          },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return DateFormat('MMM d, yyyy • h:mm a').format(dateTime);
  }
}
