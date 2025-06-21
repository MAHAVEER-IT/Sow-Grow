import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String baseUrl = 'https://api.openweathermap.org/data/2.5/weather';
  final String apiKey = 'e3d81b3dc70964e66c781d5ce8c53c63';

  // Chennai coordinates
  static const double CHENNAI_LAT = 13.0827;
  static const double CHENNAI_LON = 80.2707;

  Future<Map<String, dynamic>> getWeather() async {
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl?lat=$CHENNAI_LAT&lon=$CHENNAI_LON&units=metric&appid=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'temp': data['main']['temp'].round(), // Round to nearest integer
          'description': data['weather'][0]['main'],
          'icon': data['weather'][0]['icon'],
        };
      }
      throw Exception('Failed to load weather');
    } catch (e) {
      print('Weather error: $e');
      return {
        'temp': '--',
        'description': 'Unavailable',
        'icon': '01d',
      };
    }
  }

  String getWeatherIcon(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }
}
