class Comment {
  final String id;
  final String postId;
  final String userId;
  final String authorName;
  final String content;
  final String createdAt;
  final String? parentId;
  final List<Comment> replies;
  final int replyCount;
  final List<String> likes;
  final int likeCount;

  Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.replies = const [],
    this.replyCount = 0,
    this.likes = const [],
    this.likeCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    print('Parsing comment JSON: $json');

    // Handle different ID formats
    final String id = json['_id']?.toString() ??
        json['id']?.toString() ??
        json['commentId']?.toString() ??
        '';

    // Handle different date formats
    String createdAt = DateTime.now().toIso8601String();
    if (json['createdAt'] != null) {
      try {
        if (json['createdAt'] is String) {
          createdAt = json['createdAt'];
        } else if (json['createdAt'] is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
              .toIso8601String();
        }
      } catch (e) {
        print('Error parsing createdAt: $e');
      }
    }

    // Parse replies if they exist
    List<Comment> replies = [];
    if (json['replies'] != null) {
      replies = (json['replies'] as List)
          .map((reply) => Comment.fromJson(reply))
          .toList();
    }

    // Parse likes
    List<String> likes = [];
    if (json['likes'] != null) {
      likes = List<String>.from(json['likes']);
    }

    return Comment(
      id: id,
      postId: json['postId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? 'Anonymous',
      content: json['content']?.toString() ?? '',
      createdAt: createdAt,
      parentId: json['parentId']?.toString(),
      replies: replies,
      replyCount: json['replyCount']?.toInt() ?? 0,
      likes: likes,
      likeCount: json['likeCount']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'userId': userId,
      'authorName': authorName,
      'content': content,
      'createdAt': createdAt,
      'parentId': parentId,
      'replyCount': replyCount,
      'likeCount': likeCount,
      'likes': likes,
    };
  }

  @override
  String toString() {
    return 'Comment{id: $id, postId: $postId, userId: $userId, authorName: $authorName, content: $content, createdAt: $createdAt, parentId: $parentId, replyCount: $replyCount}';
  }
}
