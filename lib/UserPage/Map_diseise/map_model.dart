import 'package:latlong2/latlong.dart';

class DiseasePoint {
  final String id;
  final LatLng location;
  final String diseaseName;
  final String cropType;
  final double intensity;
  final int caseCount;
  final String placeName;
  final bool isPlantDisease;
  final String notes;
  final DateTime reportDate;

  DiseasePoint({
    required this.id,
    required this.location,
    required this.diseaseName,
    required this.cropType,
    required this.intensity,
    required this.caseCount,
    required this.placeName,
    required this.isPlantDisease,
    required this.notes,
    required this.reportDate,
  });

  factory DiseasePoint.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    final coordinates = (location['coordinates'] as List).cast<num>();

    return DiseasePoint(
      id: json['_id'] as String,
      location: LatLng(
        coordinates[1].toDouble(), // latitude
        coordinates[0].toDouble(), // longitude
      ),
      diseaseName: json['diseaseName'] as String,
      cropType: json['cropType'] as String,
      intensity: (json['intensity'] as num).toDouble(),
      caseCount: json['caseCount'] as int,
      placeName: json['placeName'] as String,
      isPlantDisease: json['isPlantDisease'] as bool,
      notes: json['notes'] as String? ?? '',
      reportDate: DateTime.parse(json['reportDate'] as String),
    );
  }
}
