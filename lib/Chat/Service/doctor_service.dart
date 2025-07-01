import 'dart:convert';

import 'package:http/http.dart' as http;

class Doctor {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String location;
  final String profilePic;

  Doctor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    this.profilePic = '',
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      location: json['location'] ?? '',
      profilePic: json['profilePic'] ?? '',
    );
  }
}

class DoctorService {
  static const String baseUrl =
      'https://farmcare-backend-new.onrender.com/api/v1'; // Update with your backend URL

  Future<List<Doctor>> getDoctors() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/doctors'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final List<dynamic> doctorsJson = responseData['data'];
          return doctorsJson.map((json) => Doctor.fromJson(json)).toList();
        }
      }
      throw Exception('Failed to load doctors');
    } catch (e) {
      print('Error fetching doctors: $e');
      throw Exception('Failed to load doctors');
    }
  }
}
