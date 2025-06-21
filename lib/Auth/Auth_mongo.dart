import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart' as prefs;

class AuthService {
  // Update this to your actual backend URL
  final String baseUrl = 'https://farmcare-backend-new.onrender.com/api/v1';
  // Use 10.0.2.2 for Android emulator to connect to localhost
  // For physical device, use your computer's IP address
  // For iOS simulator, use localhost

  Future<Map<String, dynamic>> signup({
    required String username,
    required String password,
    required String email,
    required String phone,
    required String name,
    required String userType, // Add this field
    required String location, // Add this parameter
  }) async {
    try {
      // Generate a UUID for userId
      final userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Register user with all required fields
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'username': username,
          'password': password,
          'email': email,
          'name': name, // Add name to main user registration
          'phone': phone, // Add phone to main user registration
          'userType': userType, // Add userType to main user registration
          'location': location, // Add this field
          'lastLogin': DateTime.now().toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        // Create additional user details if needed
        final userDetailsResponse = await http.post(
          Uri.parse('$baseUrl/userdetails/create'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': userId,
            'name': name,
            'email': email,
            'phone': phone,
            'userType': userType,
            'location': location, // Pass the location here
            'animalTypes': [], // Optional field
          }),
        );

        if (userDetailsResponse.statusCode <= 200 ||
            userDetailsResponse.statusCode >= 299) {
          return {
            'success': true,
            'message': 'Registration successful',
            'userId': userId
          };
        } else {
          throw Exception('Failed to create user details');
        }
      } else {
        final error = json.decode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      print('Registration error: $e'); // Add debug logging
      return {'success': false, 'message': 'Registration failed: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      print('Attempting login with username: $username');
      print('Login URL: $baseUrl/auth/login');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      print('Login response status: ${response.statusCode}');
      print('Login response body: ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          throw Exception('Empty response from server');
        }

        final data = json.decode(response.body);
        if (data['token'] != null) {
          // Validate token before saving
          if (data['token'].toString().isEmpty) {
            throw Exception('Invalid token received');
          }

          // Save token and user data in SharedPreferences with error handling
          try {
            await DatabaseService.saveUser(
              data['userId'],
              username,
              data['token'],
              data['name'] ?? '',
              data['email'] ?? '',
              data['userType'] ?? 'user',
              data['location'] ?? 'Coimbatore',
            );
          } catch (e) {
            print('Error saving user data: $e');
            throw Exception('Failed to save user data locally');
          }

          print('Login successful - Token received and saved');
          return {
            'success': true,
            'message': 'Login successful',
            'token': data['token'],
            'userId': data['userId'],
            'location': data['location'] ?? 'Coimbatore',
          };
        } else {
          print('Login failed - No token in response');
          return {
            'success': false,
            'message': 'Login failed: Invalid server response',
          };
        }
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Invalid username or password',
        };
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'User not found',
        };
      } else {
        print('Login failed - Server response: ${response.body}');
        final data =
            response.body.isNotEmpty ? json.decode(response.body) : null;
        return {
          'success': false,
          'message': data?['message'] ?? 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Login error: $e');
      return {
        'success': false,
        'message': 'Login failed: ${e.toString()}',
      };
    }
  }

  Future<void> _saveAuthData(String token, String userId) async {
    try {
      final storage = await prefs.SharedPreferences.getInstance();
      await storage.setString('token', token);
      await storage.setString('userId', userId);
      print('Auth data saved successfully');
    } catch (e) {
      print('Error saving auth data: $e');
      throw Exception('Failed to save authentication data');
    }
  }

  Future<bool> isLoggedIn() async {
    final storage = await prefs.SharedPreferences.getInstance();
    return storage.getString('token') != null;
  }

  Future<void> logout() async {
    await DatabaseService.instance.logout();
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();

  DatabaseService._init();

  static Future<void> saveUser(
    String userId,
    String username,
    String token,
    String name,
    String email,
    String userType,
    String location, // Add location parameter
  ) async {
    try {
      final storage = await prefs.SharedPreferences.getInstance();
      await storage.setString('userId', userId);
      await storage.setString('username', username);
      await storage.setString('token', token);
      await storage.setString('name', name);
      await storage.setString('email', email);
      await storage.setString('userType', userType);
      await storage.setString('location', location);
      print('User data saved in local storage');
    } catch (e) {
      print('Error saving user data: $e');
      throw Exception('Failed to save user data');
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final storage = await prefs.SharedPreferences.getInstance();
      final token = storage.getString('token');
      final userId = storage.getString('userId');
      return token != null && userId != null;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final storage = await prefs.SharedPreferences.getInstance();
      await storage.clear();
      print('User logged out - Local storage cleared');
    } catch (e) {
      print('Error during logout: $e');
      throw Exception('Failed to logout');
    }
  }
}
