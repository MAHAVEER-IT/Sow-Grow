import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather/weather.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import '../Map_diseise/map_service.dart';
import '../Map_diseise/map_model.dart';
import '../Map_diseise/Dedict_desisease.dart'; // Add this import
import 'const.dart';

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
          List<Location> locations =
              await locationFromAddress("Angalakurichi, Tamil Nadu, India");
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
          'Location set to: $_userLocation ($_latitude, $_longitude)'); // Debug log

      // Fetch both weather and diseases
      await _fetchWeather();
      if (_latitude != null && _longitude != null) {
        await _fetchNearbyDiseases();
      }
    } catch (e) {
      print('Error loading user location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading location: $e')),
      );
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
      Weather weather =
          await _weatherFactory.currentWeatherByCityName(_userLocation);
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
                "Could not fetch weather for $_userLocation. Please try again later.")),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF2E7D32), // Dark green
              Color(0xFF43A047), // Medium green
              Color(0xFF66BB6A), // Light green
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
                            child:
                                CircularProgressIndicator(color: Colors.white))
                      else if (_weather == null)
                        _buildErrorState()
                      else
                        _buildWeatherDetails(),
                      const SizedBox(height: 20),
                      _buildNearbyDiseases(),
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
            icon: const Icon(Icons.arrow_back_ios_sharp, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              "Weather Forecast",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: _fetchWeather,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: "Refresh weather data",
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 100,
            color: Colors.white.withOpacity(0.7),
          ),
          const SizedBox(height: 20),
          Text(
            "Could not load weather for $_userLocation",
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchWeather,
            icon: const Icon(Icons.refresh),
            label: const Text("Try Again"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade800,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
          _buildLocationHeader(),
          const SizedBox(height: 30),
          _buildCurrentWeather(),
          const SizedBox(height: 40),
          _buildWeatherGrid(),
        ],
      ),
    );
  }

  Widget _buildLocationHeader() {
    DateTime now = _weather?.date ?? DateTime.now();
    return Column(
      children: [
        Text(
          _userLocation.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              "${DateFormat("EEEE").format(now)}, ${DateFormat("d MMM, yyyy").format(now)}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentWeather() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Image.network(
                  "http://openweathermap.org/img/wn/${_weather?.weatherIcon}@4x.png",
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_weather?.temperature?.celsius?.toStringAsFixed(0)}°C",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _weather?.weatherDescription?.toUpperCase() ?? "",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherStat(
                Icons.thermostat,
                "Feels Like",
                "${_weather?.tempFeelsLike?.celsius?.toStringAsFixed(0)}°C",
              ),
              _buildWeatherStat(
                Icons.water_drop,
                "Humidity",
                "${_weather?.humidity?.toStringAsFixed(0)}%",
              ),
              _buildWeatherStat(
                Icons.air,
                "Wind",
                "${_weather?.windSpeed?.toStringAsFixed(1)} m/s",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Weather Details",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildInfoTile(
              "MIN TEMPERATURE",
              "${_weather?.tempMin?.celsius?.toStringAsFixed(0)}°C",
              Icons.arrow_downward,
            ),
            _buildInfoTile(
              "MAX TEMPERATURE",
              "${_weather?.tempMax?.celsius?.toStringAsFixed(0)}°C",
              Icons.arrow_upward,
            ),
            _buildInfoTile(
              "PRESSURE",
              "${_weather?.pressure?.toStringAsFixed(0)} hPa",
              Icons.speed,
            ),
            _buildInfoTile(
              "CLOUDINESS",
              "${_weather?.cloudiness?.toStringAsFixed(0)}%",
              Icons.cloud,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyDiseases() {
    if (_isLoadingDiseases) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_nearbyDiseases.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            "No disease reports found in your area",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Nearby Disease Reports (100km radius)",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _nearbyDiseases.length,
            itemBuilder: (context, index) {
              final disease = _nearbyDiseases[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  // Wrap with InkWell to make it tappable
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HeatmapPageMap(
                          initialLocation: disease.location,
                          selectedDisease: disease,
                        ),
                      ),
                    );
                  },
                  child: ListTile(
                    leading: Icon(
                      disease.isPlantDisease ? Icons.local_florist : Icons.pets,
                      color: Colors.white,
                      size: 28,
                    ),
                    title: Text(
                      disease.diseaseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          disease.isPlantDisease
                              ? "Crop: ${disease.cropType}"
                              : "Animal Disease",
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                        Text(
                          "Location: ${disease.placeName}",
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                        Text(
                          "Cases: ${disease.caseCount}",
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getIntensityColor(disease.intensity),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${(disease.intensity * 100).toInt()}%",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getIntensityColor(double intensity) {
    if (intensity < 0.3) {
      return Colors.green;
    } else if (intensity < 0.7) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
