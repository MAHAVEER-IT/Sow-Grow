import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:weather/weather.dart';
import 'weather_widgets.dart';

/// Location header widget showing city name and date
class WeatherLocationHeader extends StatelessWidget {
  final String location;
  final DateTime? date;

  const WeatherLocationHeader({super.key, required this.location, this.date});

  @override
  Widget build(BuildContext context) {
    DateTime now = date ?? DateTime.now();
    return Column(
      children: [
        Text(
          location.toUpperCase(),
          style: TextStyle(
            color: Colors.green.shade800,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, color: Colors.green.shade700, size: 16),
            const SizedBox(width: 8),
            Text(
              "${DateFormat("EEEE").format(now)}, ${DateFormat("d MMM, yyyy").format(now)}",
              style: TextStyle(color: Colors.green.shade700, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }
}

/// Current weather display widget with temperature and conditions
class CurrentWeatherCard extends StatelessWidget {
  final Weather weather;

  const CurrentWeatherCard({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  "http://openweathermap.org/img/wn/${weather.weatherIcon}@4x.png",
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, color: Colors.red, size: 50),
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${weather.temperature?.celsius?.toStringAsFixed(0)}°C",
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    weather.weatherDescription?.toUpperCase() ?? "",
                    style: TextStyle(
                      color: Colors.green.shade700,
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
              WeatherStatWidget(
                icon: Icons.thermostat,
                label: "Feels Like",
                value:
                    "${weather.tempFeelsLike?.celsius?.toStringAsFixed(0)}°C",
              ),
              WeatherStatWidget(
                icon: Icons.water_drop,
                label: "Humidity",
                value: "${weather.humidity?.toStringAsFixed(0)}%",
              ),
              WeatherStatWidget(
                icon: Icons.air,
                label: "Wind",
                value: "${weather.windSpeed?.toStringAsFixed(1)} m/s",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Weather details grid showing min/max temp, pressure, cloudiness
class WeatherDetailsGrid extends StatelessWidget {
  final Weather weather;

  const WeatherDetailsGrid({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Weather Details",
          style: TextStyle(
            color: Colors.green.shade800,
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
            WeatherInfoTile(
              title: "MIN TEMPERATURE",
              value: "${weather.tempMin?.celsius?.toStringAsFixed(0)}°C",
              icon: Icons.arrow_downward,
            ),
            WeatherInfoTile(
              title: "MAX TEMPERATURE",
              value: "${weather.tempMax?.celsius?.toStringAsFixed(0)}°C",
              icon: Icons.arrow_upward,
            ),
            WeatherInfoTile(
              title: "PRESSURE",
              value: "${weather.pressure?.toStringAsFixed(0)} hPa",
              icon: Icons.speed,
            ),
            WeatherInfoTile(
              title: "CLOUDINESS",
              value: "${weather.cloudiness?.toStringAsFixed(0)}%",
              icon: Icons.cloud,
            ),
          ],
        ),
      ],
    );
  }
}
