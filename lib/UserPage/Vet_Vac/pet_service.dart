// lib/services/pet_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'Vaccine_Model.dart';
import 'Vet_page.dart' as vet_page;

class PetService {
  final String baseUrl = 'https://farmcare-backend-new.onrender.com/api/v1';

  // Get the auth token from shared preferences
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    print(
        'Retrieved token: ${token.isNotEmpty ? "Token exists" : "Token empty"}');
    return token;
  }

  // Headers for authenticated requests
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all pets for the current user
  Future<List<Pet>> getPets() async {
    try {
      final headers = await _getHeaders();
      print('Requesting pets with headers: $headers');

      final response = await http.get(
        Uri.parse('$baseUrl/pets'),
        headers: headers,
      );

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          final petsList = (jsonData['data'] as List)
              .map((petJson) => Pet.fromJson(petJson))
              .toList();
          print('Parsed ${petsList.length} pets');
          return petsList;
        }
        print('No pets found in response data');
        return [];
      } else {
        throw Exception(
            'Failed to load pets: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('Error getting pets: $e');
      return [];
    }
  }

  // Get a specific pet
  Future<Pet?> getPet(String petId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/pets/$petId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          return Pet.fromJson(jsonData['data']);
        }
        return null;
      } else {
        throw Exception('Failed to load pet: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting pet: $e');
      return null;
    }
  }

  // Create a new pet
  Future<Pet?> createPet(Pet pet) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/pets'),
        headers: headers,
        body: json.encode(pet.toJson()),
      );

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          return Pet.fromJson(jsonData['data']);
        }
        return null;
      } else {
        throw Exception('Failed to create pet: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating pet: $e');
      return null;
    }
  }

  // Update an existing pet
  Future<Pet?> updatePet(Pet pet) async {
    try {
      final headers = await _getHeaders();
      final petJson = pet.toJson();

      // Remove properties that shouldn't be sent
      petJson.remove('vaccinations');

      final response = await http.put(
        Uri.parse('$baseUrl/pets/${pet.id}'),
        headers: headers,
        body: json.encode(petJson),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          return Pet.fromJson(jsonData['data']);
        }
        return null;
      } else {
        throw Exception('Failed to update pet: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating pet: $e');
      return null;
    }
  }

  // Delete a pet
  Future<bool> deletePet(String petId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/pets/$petId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return jsonData['success'] ?? false;
      }
      return false;
    } catch (e) {
      print('Error deleting pet: $e');
      return false;
    }
  }

  // Add a vaccination to a pet
  Future<Pet?> addVaccination(String petId, Vaccination vaccination) async {
    try {
      final headers = await _getHeaders();

      // Validate required fields
      if (vaccination.name.isEmpty) {
        throw Exception('Vaccination name is required');
      }

      // Prepare the request body
      final requestBody = {
        'name': vaccination.name,
        'dueDate': vaccination.dueDate.toIso8601String(),
        'notes': vaccination.notes ?? '', // Handle null notes
        'isRecurring':
            vaccination.isRecurring ?? false, // Handle null isRecurring
      };

      print('Adding vaccination with body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/pets/$petId/vaccinations'),
        headers: headers,
        body: json.encode(requestBody),
      );

      print(
          'Add vaccination response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          return Pet.fromJson(jsonData['data']);
        }
        throw Exception('Invalid response format: ${response.body}');
      } else {
        throw Exception(
            'Failed to add vaccination: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error adding vaccination: $e');
      return null;
    }
  }

  // Delete a vaccination
  Future<Pet?> deleteVaccination(String petId, String vaccinationId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/pets/$petId/vaccinations/$vaccinationId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          return Pet.fromJson(jsonData['data']);
        }
        return null;
      } else {
        throw Exception('Failed to delete vaccination: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting vaccination: $e');
      return null;
    }
  }

  // Get upcoming vaccinations
  Future<List<Map<String, dynamic>>> getUpcomingVaccinations(
      {int days = 30}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/pets/upcoming-vaccinations?days=$days'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData['success'] && jsonData['data'] != null) {
          return List<Map<String, dynamic>>.from(jsonData['data']);
        }
        return [];
      } else {
        throw Exception(
            'Failed to get upcoming vaccinations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting upcoming vaccinations: $e');
      return [];
    }
  }
}
