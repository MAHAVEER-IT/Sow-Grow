import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Add MediaType import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sow_and_grow/UserPage/Blog/Blog_UI.dart';

import 'Models/comment.dart';

class BlogService {
  final String baseUrl = 'https://farmcare-backend-new.onrender.com/api/v1';

  // Improved token handling
  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      return token.startsWith('Bearer ') ? token : 'Bearer $token';
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  // Check if token is valid and refresh if needed
  Future<bool> _ensureValidToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final refreshToken = prefs.getString('refreshToken');

      if (token == null) return false;

      // If we have a refresh token, try to refresh the access token
      if (refreshToken != null) {
        try {
          final response = await http.post(
            Uri.parse('$baseUrl/auth/refresh-token'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refreshToken': refreshToken}),
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['token'] != null) {
              // Save the new token
              await prefs.setString('token', data['token']);
              return true;
            }
          }
        } catch (e) {
          print('Token refresh error: $e');
        }
      }

      return token != null;
    } catch (e) {
      print('Error ensuring valid token: $e');
      return false;
    }
  }

  // Helper method for headers
  Future<Map<String, String>> _getHeaders() async {
    // Try to ensure we have a valid token
    await _ensureValidToken();

    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  Future<List<BlogPost>> getAllPosts() async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .get(Uri.parse('$baseUrl/posts/getposts'), headers: headers)
          .timeout(const Duration(seconds: 30));

      print('Posts response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['posts'] == null) throw Exception('Posts data is null');
        final List<dynamic> posts = data['posts'];
        return posts.map((post) => BlogPost.fromJson(post)).toList();
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching posts: $e');
      rethrow;
    }
  }

  // Get posts by user
  Future<List<Map<String, dynamic>>> getPostsByUser(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/getpost/user/$userId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['posts']);
      } else {
        throw Exception('Failed to load user posts');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Add like to post
  Future<void> addLike(String postId, String userId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/posts/addlike/$postId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'likeUserId': userId}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to like post');
      }
    } catch (e) {
      throw Exception('Error: $e');
    }
  }

  // Updated getComments method
  Future<List<Comment>> getComments(String postId) async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .get(Uri.parse('$baseUrl/comments/$postId'), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> commentsJson = data['comments'] ?? [];
        return commentsJson.map((json) => Comment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load comments: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting comments: $e');
      rethrow;
    }
  }

  // Updated addComment method
  Future<Comment> addComment(
    String postId,
    String userId,
    String content,
  ) async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/comments/create'),
        headers: headers,
        body: json.encode({'postId': postId, 'content': content}),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['comment'] != null) {
          return Comment.fromJson(data['comment']);
        }
        throw Exception(data['message'] ?? 'Failed to add comment');
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(File imageFile) async {
    try {
      // Create multipart form request
      final url = Uri.parse('$baseUrl/photos/upload');
      var request = http.MultipartRequest('POST', url);

      // Add the file to the request
      final multipartFile = await http.MultipartFile.fromPath(
        'image', // field name must match backend
        imageFile.path,
        contentType: MediaType('image', 'jpeg'), // Explicitly set content type
      );

      request.files.add(multipartFile);

      // Set headers if needed
      request.headers.addAll({'Accept': 'application/json'});

      // Log request details
      print('Uploading file: ${imageFile.path}');
      print('To URL: $url');
      print('Content type: ${multipartFile.contentType}');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['imageUrl'] != null) {
          return data['imageUrl'];
        }
        throw Exception('No image URL in response');
      } else {
        throw Exception('Upload failed: ${response.body}');
      }
    } catch (e) {
      print('Upload error: $e');
      rethrow;
    }
  }

  Future<void> createPost({
    required String content,
    required String userId,
    required String authorName,
    File? imageFile,
  }) async {
    try {
      String? imageUrl;

      // Upload image only if provided
      if (imageFile != null) {
        try {
          imageUrl = await uploadImage(imageFile);
        } catch (e) {
          print('Image upload failed: $e');
          // Continue creating post without image
        }
      }

      // Create post with optional image URL
      final response = await http.post(
        Uri.parse('$baseUrl/posts/createpost'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'content': content,
          'images': imageUrl != null
              ? [imageUrl]
              : [], // Include image only if upload succeeded
          'authorName': authorName,
          'postType': 'farmUpdate',
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode != 201) {
        print('Create post failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to create post');
      }
    } catch (e) {
      print('Create post error: $e');
      throw Exception('Error creating post: $e');
    }
  }

  Future<void> updateLike(String postId, String userId) async {
    try {
      // Ensure we have a valid token before making the request
      final tokenValid = await _ensureValidToken();
      if (!tokenValid) {
        throw Exception('Not authenticated');
      }

      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      print('Updating like for post: $postId, user: $userId');
      print('Headers: $headers');

      final response = await http.post(
        Uri.parse('$baseUrl/posts/like'),
        headers: headers,
        body: json.encode({'postId': postId, 'userId': userId}),
      );

      print('Like update response: ${response.statusCode}, ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to update like: ${response.body}');
      }
    } catch (e) {
      print('Like update error: $e');
      throw Exception('Failed to update like: $e');
    }
  }

  Future<void> createBlog({
    required String title,
    required String content,
    File? imageFile, // Changed from String? imageUrl to File? imageFile
    required String userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      String? imageId;
      if (imageFile != null) {
        // Upload image to MongoDB and get the ID
        imageId = await uploadBlogImage(imageFile);
      }
      final response = await http.post(
        Uri.parse('$baseUrl/posts/createpost'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'title': title,
          'content': content,
          'imageId': imageId, // Store MongoDB image ID instead of URL
          'postType': 'farmUpdate',
          'userId': userId,
          'createdAt': DateTime.now().toIso8601String(),
        }),
      );

      print('Create blog response: ${response.body}');

      if (response.statusCode != 201) {
        throw Exception('Failed to create blog: ${response.body}');
      }
    } catch (e) {
      print('Blog creation error: $e');
      rethrow;
    }
  }

  Future<String> uploadBlogImage(File imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('Not authenticated');
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/photos/upload'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add file
      var multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
      );
      request.files.add(multipartFile);

      // Send request
      var response = await request.send();
      var responseString = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final data = json.decode(responseString);
        return data['imageUrl'];
      }
      throw Exception('Failed to upload image: $responseString');
    } catch (e) {
      print('Image upload error: $e');
      rethrow;
    }
  }

  // Get replies for a comment
  Future<List<Comment>> getReplies(String commentId) async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .get(
            Uri.parse('$baseUrl/comments/$commentId/replies'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> repliesJson = data['replies'] ?? [];
        return repliesJson.map((json) => Comment.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load replies: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting replies: $e');
      rethrow;
    }
  }

  // Add reply to a comment
  Future<Comment> addReply(String commentId, String content) async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/comments/$commentId/reply'),
        headers: headers,
        body: json.encode({'content': content}),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['reply'] != null) {
          return Comment.fromJson(data['reply']);
        }
        throw Exception(data['message'] ?? 'Failed to add reply');
      } else {
        throw Exception('Failed to add reply: ${response.statusCode}');
      }
    } catch (e) {
      print('Error adding reply: $e');
      rethrow;
    }
  }
}
