import 'package:flutter/material.dart';
import 'package:weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../../Map_diseise/Service/map_service.dart';
import '../../Map_diseise/Model/map_model.dart';
import '../utility/const.dart';
import '../Widgets/weather_widgets.dart';
import '../Widgets/weather_display_widgets.dart';
import '../Widgets/disease_card_widget.dart';

class WeatherDetail extends StatefulWidget {
  const WeatherDetail({super.key});

  @override
  State<WeatherDetail> createState() => _WeatherDetailState();
}

class _WeatherDetailState extends State<WeatherDetail> {
  final WeatherFactory _weatherFactory = WeatherFactory(OPEN_WEATHER_API_KEY);
  final DiseasePointService _diseaseService = DiseasePointService();
  Weather? _weather;
  bool _isLoading = false;
  bool _isLoadingDiseases = false;
  String _userLocation = "";
  List<DiseasePoint> _nearbyDiseases = [];
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final location = prefs.getString('location') ?? "Angalakurichi";

      // First try to get coordinates from prefs
      double? lat = prefs.getDouble('latitude');
      double? lon = prefs.getDouble('longitude');

      // If not found in prefs, use geocoding to get coordinates for Angalakurichi
      if (lat == null || lon == null) {
        try {
          List<Location> locations = await locationFromAddress(
            "Angalakurichi, Tamil Nadu, India",
          );
          if (locations.isNotEmpty) {
            lat = locations.first.latitude;
            lon = locations.first.longitude;

            // Save the coordinates for future use
            await prefs.setDouble('latitude', lat);
            await prefs.setDouble('longitude', lon);
          }
        } catch (e) {
          print('Geocoding error: $e');
          // Fallback to known coordinates for Angalakurichi
          lat = 10.5677;
          lon = 77.0921;
        }
      }

      setState(() {
        _userLocation = location;
        _latitude = lat;
        _longitude = lon;
      });

      print(
        'Location set to: $_userLocation ($_latitude, $_longitude)',
      ); // Debug log

      // Fetch both weather and diseases
      await _fetchWeather();
      if (_latitude != null && _longitude != null) {
        await _fetchNearbyDiseases();
      }
    } catch (e) {
      print('Error loading user location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading location: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Weather weather = await _weatherFactory.currentWeatherByCityName(
        _userLocation,
      );
      setState(() {
        _weather = weather;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Could not fetch weather for $_userLocation. Please try again later.",
          ),
        ),
      );
    }
  }

  Future<void> _fetchNearbyDiseases() async {
    if (_latitude == null || _longitude == null) return;

    setState(() {
      _isLoadingDiseases = true;
    });

    try {
      print('Fetching diseases near: $_latitude, $_longitude'); // Debug log
      final diseases = await _diseaseService.getNearbyDiseasePoints(
        latitude: _latitude!,
        longitude: _longitude!,
        radiusKm: 100,
      );

      print('Found ${diseases.length} nearby diseases'); // Debug log

      if (mounted) {
        setState(() {
          _nearbyDiseases = diseases;
          _isLoadingDiseases = false;
        });
      }
    } catch (e) {
      print('Error fetching nearby diseases: $e');
      if (mounted) {
        setState(() {
          _isLoadingDiseases = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch nearby disease reports: $e'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade50, Colors.green.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.green),
                        )
                      else if (_weather == null)
                        WeatherErrorState(
                          location: _userLocation,
                          onRetry: _fetchWeather,
                        )
                      else
                        _buildWeatherDetails(),
                      const SizedBox(height: 20),
                      NearbyDiseasesSection(
                        isLoading: _isLoadingDiseases,
                        diseases: _nearbyDiseases,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_sharp,
              color: Colors.green.shade800,
            ),
          ),
          Expanded(
            child: Text(
              "Weather Forecast",
              style: TextStyle(
                color: Colors.green.shade800,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _fetchWeather,
            icon: Icon(Icons.refresh, color: Colors.green.shade800),
            tooltip: "Refresh weather data",
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherDetails() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          WeatherLocationHeader(location: _userLocation, date: _weather?.date),
          const SizedBox(height: 30),
          CurrentWeatherCard(weather: _weather!),
          const SizedBox(height: 40),
          WeatherDetailsGrid(weather: _weather!),
        ],
      ),
    );
  }
}
