import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateBlogService {
  final String baseUrl = 'https://farmcare-backend-new.onrender.com/api/v1';

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

  Future<Map<String, String>> _getHeaders({bool isMultipart = false}) async {
    final token = await _getToken();
    return {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': token,
    };
  }

  Future<String> uploadBlogImage(File imageFile) async {
    try {
      final headers = await _getHeaders(isMultipart: true);
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      // Validate file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      // Validate file size
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

      print('Starting image upload...');
      print('File path: ${imageFile.path}');
      print('File size: ${length / 1024 / 1024}MB');
      print('MIME type: $mimeType');

      // Create upload request
      final uri = Uri.parse('$baseUrl/photos/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll(headers);

      // Add file to request with proper content type
      final stream = http.ByteStream(imageFile.openRead());
      final multipartFile = http.MultipartFile(
        'image',
        stream,
        length,
        filename: imageFile.path.split('/').last,
        contentType: MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
      );
      request.files.add(multipartFile);

      print('Sending request to: $uri');
      print('Headers: $headers');

      // Send request with timeout
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Upload timed out. Please try again.');
        },
      );

      // Get response
      final response = await http.Response.fromStream(streamedResponse);
      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['imageUrl'] != null) {
          // Handle both local and Cloudinary URLs
          String imageUrl = data['imageUrl'];
          if (!imageUrl.startsWith('http')) {
            imageUrl = 'https://farmer-backend-r34r.onrender.com' + imageUrl;
          }
          print('Upload successful. Image URL: $imageUrl');
          return imageUrl;
        }
        throw Exception('No image URL in response');
      }

      // Handle specific error cases
      switch (response.statusCode) {
        case 413:
          throw Exception(
              'Image size too large for server. Please choose a smaller image.');
        case 415:
          throw Exception(
              'Unsupported image format. Please choose a different image.');
        case 401:
          throw Exception('Not authenticated. Please log in again.');
        default:
          throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } on TimeoutException {
      print('Upload timed out');
      rethrow;
    } catch (e) {
      print('Image upload error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createBlog({
    required String title,
    required String content,
    File? imageFile,
  }) async {
    try {
      final headers = await _getHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Not authenticated');
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final authorName = prefs.getString('username') ?? 'Anonymous';

      if (userId == null) {
        throw Exception('User ID not found');
      }

      String? imageUrl;
      if (imageFile != null) {
        try {
          imageUrl = await uploadBlogImage(imageFile);
        } catch (e) {
          print('Image upload failed: $e');
          return {
            'success': false,
            'message': 'Failed to upload image: $e',
          };
        }
      }

      final response = await http
          .post(
        Uri.parse('$baseUrl/posts/createpost'),
        headers: headers,
        body: json.encode({
          'userId': userId,
          'authorName': authorName,
          'title': title,
          'content': content,
          'images': imageUrl != null ? [imageUrl] : [],
          'postType': 'farmUpdate',
          'createdAt': DateTime.now().toIso8601String(),
        }),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Request timed out. Please try again.');
        },
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data};
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ??
            'Failed to create blog: ${response.statusCode}');
      }
    } catch (e) {
      print('Blog creation error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
