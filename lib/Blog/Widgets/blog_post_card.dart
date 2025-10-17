import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../UI/Blog_UI.dart';
import '../UI/post_detail.dart';
import '../../utils/Language/app_localizations.dart';
import '../../utils/Language/language_provider.dart';

/// Reusable blog post card widget
class BlogPostCard extends StatelessWidget {
  final BlogPost post;
  final String? userId;
  final Function(String) onLike;
  final Function(String) onComment;
  final List<String> defaultImages;

  const BlogPostCard({
    super.key,
    required this.post,
    required this.userId,
    required this.onLike,
    required this.onComment,
    required this.defaultImages,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 5,
        margin: EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostImage(),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthorInfo(),
                  SizedBox(height: 12),
                  _buildPostTitle(),
                  SizedBox(height: 8),
                  _buildPostContent(),
                  SizedBox(height: 16),
                  _buildActionBar(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImage() {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      child: Image.network(
        post.images.isNotEmpty
            ? post.images.first
            : defaultImages[post.postId.hashCode % defaultImages.length],
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Image.network(
            defaultImages[post.postId.hashCode % defaultImages.length],
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey[300],
                child: Icon(
                  Icons.agriculture,
                  size: 64,
                  color: Colors.grey[600],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAuthorInfo() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
            "https://ui-avatars.com/api/?name=${Uri.encodeComponent(post.authorName.replaceAll(' ', '+'))}",
          ),
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.authorName,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              post.createdAt.toString(),
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostTitle() {
    return Text(
      post.title,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildPostContent() {
    return Text(
      post.content,
      style: TextStyle(fontSize: 16),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            post.likeUsers.contains(userId)
                ? Icons.favorite
                : Icons.favorite_border,
            color: post.likeUsers.contains(userId) ? Colors.red : null,
          ),
          onPressed: () => onLike(post.postId),
        ),
        Text('${post.likeCount}'),
        SizedBox(width: 16),
        IconButton(
          icon: Icon(Icons.comment_outlined),
          onPressed: () => onComment(post.postId),
        ),
        Text('${post.commentCount}'),
        Spacer(),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(post: post),
              ),
            );
          },
          child: Text(
            AppLocalizations.translate(
              'readMore',
              Provider.of<LanguageProvider>(context).currentLanguage,
            ),
            style: TextStyle(color: Colors.green.shade600),
          ),
        ),
      ],
    );
  }
}
