import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Model/map_model.dart';

class DiseasePointService {
  // Base URL for API
  final String baseUrl =
      'https://farmcare-backend-new.onrender.com/api/v1/disease-points';

  // Get auth token from shared preferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Create headers with auth token
  Future<Map<String, String>> _createHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<DiseasePoint>> getAllDiseasePoints({
    bool? isPlantDisease,
    DateTime? startDate,
    DateTime? endDate,
    String? diseaseName,
    String? cropType,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};

      if (isPlantDisease != null) {
        queryParams['isPlantDisease'] = isPlantDisease.toString();
      }

      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }

      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }

      if (diseaseName != null) {
        queryParams['diseaseName'] = diseaseName;
      }

      if (cropType != null) {
        queryParams['cropType'] = cropType;
      }

      // Create URI with query parameters
      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);

      // Send request
      final response = await http.get(uri, headers: await _createHeaders());

      // Check response
      if (response.statusCode == 200) {
        print('API Response Body: ${response.body}'); // Debug print
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> pointsJson = data['data'];
          return pointsJson
              .map((pointJson) => DiseasePoint.fromJson(pointJson))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch disease points');
        }
      } else {
        throw Exception(
          'Failed to fetch disease points: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getAllDiseasePoints: $e');
      throw Exception('Failed to fetch disease points: $e');
    }
  }

  // Get nearby disease points based on coordinates and radius
  Future<List<DiseasePoint>> getNearbyDiseasePoints({
    required double latitude,
    required double longitude,
    double radiusKm = 100, // Default to 100km radius
    bool? isPlantDisease,
  }) async {
    try {
      print(
        'Searching for diseases near: $latitude, $longitude with ${radiusKm}km radius',
      ); // Debug log

      // Build query parameters
      final queryParams = <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radiusKm': radiusKm.toString(),
      };

      if (isPlantDisease != null) {
        queryParams['isPlantDisease'] = isPlantDisease.toString();
      }

      // Create URI with query parameters
      final uri = Uri.parse(
        '$baseUrl/nearby',
      ).replace(queryParameters: queryParams);

      print('Request URL: $uri'); // Debug log

      // Send request
      final headers = await _createHeaders();
      print('Request headers: $headers'); // Debug log

      final response = await http.get(uri, headers: headers);

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      // Check response
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> pointsJson = data['data'];
          return pointsJson.map((pointJson) {
            try {
              return DiseasePoint.fromJson(pointJson);
            } catch (e) {
              print('Error parsing disease point: $e');
              rethrow;
            }
          }).toList();
        } else {
          throw Exception(
            data['message'] ?? 'Failed to fetch nearby disease points',
          );
        }
      } else {
        throw Exception(
          'Failed to fetch nearby disease points: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getNearbyDiseasePoints: $e');
      throw Exception('Failed to fetch nearby disease points: $e');
    }
  }

  // Get a single disease point by ID
  Future<DiseasePoint> getDiseasePointById(String id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/$id'),
        headers: await _createHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return DiseasePoint.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch disease point');
        }
      } else {
        throw Exception(
          'Failed to fetch disease point: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in getDiseasePointById: $e');
      throw Exception('Failed to fetch disease point: $e');
    }
  }

  // Create a new disease point
  Future<DiseasePoint> createDiseasePoint({
    required double latitude,
    required double longitude,
    required String diseaseName,
    required String cropType,
    required double intensity,
    required int caseCount,
    required String placeName,
    required bool isPlantDisease,
    String? notes,
  }) async {
    try {
      final body = json.encode({
        'latitude': latitude,
        'longitude': longitude,
        'diseaseName': diseaseName,
        'cropType': cropType,
        'intensity': intensity,
        'caseCount': caseCount,
        'placeName': placeName,
        'isPlantDisease': isPlantDisease,
        'notes': notes ?? '',
      });

      print('Creating disease point with data: $body'); // Debug log

      final headers = await _createHeaders();
      print('Request headers: $headers'); // Debug log

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: body,
      );

      print('Server response status: ${response.statusCode}'); // Debug log
      print('Server response body: ${response.body}'); // Debug log

      if (response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return DiseasePoint.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to create disease point');
        }
      } else {
        throw Exception(
          'Failed to create disease point: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in createDiseasePoint: $e');
      throw Exception('Failed to create disease point: $e');
    }
  }

  // Update a disease point
  Future<DiseasePoint> updateDiseasePoint({
    required String id,
    String? diseaseName,
    String? cropType,
    double? intensity,
    int? caseCount,
    String? notes,
  }) async {
    try {
      // Build update body with only the fields that need to be updated
      final Map<String, dynamic> updateData = {};

      if (diseaseName != null) updateData['diseaseName'] = diseaseName;
      if (cropType != null) updateData['cropType'] = cropType;
      if (intensity != null) updateData['intensity'] = intensity;
      if (caseCount != null) updateData['caseCount'] = caseCount;
      if (notes != null) updateData['notes'] = notes;

      final body = json.encode(updateData);

      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: await _createHeaders(),
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return DiseasePoint.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to update disease point');
        }
      } else {
        throw Exception(
          'Failed to update disease point: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in updateDiseasePoint: $e');
      throw Exception('Failed to update disease point: $e');
    }
  }

  // Delete a disease point
  Future<bool> deleteDiseasePoint(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: await _createHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        throw Exception(
          'Failed to delete disease point: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error in deleteDiseasePoint: $e');
      throw Exception('Failed to delete disease point: $e');
    }
  }
}
