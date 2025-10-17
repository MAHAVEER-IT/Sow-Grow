import 'package:flutter/material.dart';
import '../../Map_diseise/Model/map_model.dart';
import '../../Map_diseise/UI/Dedict_desisease.dart';
import 'weather_widgets.dart';

/// Reusable disease card widget
class DiseaseCardWidget extends StatelessWidget {
  final DiseasePoint disease;

  const DiseaseCardWidget({super.key, required this.disease});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
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
            color: Colors.green.shade600,
            size: 28,
          ),
          title: Text(
            disease.diseaseName,
            style: TextStyle(
              color: Colors.green.shade800,
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
                style: TextStyle(color: Colors.grey.shade700),
              ),
              Text(
                "Location: ${disease.placeName}",
                style: TextStyle(color: Colors.grey.shade700),
              ),
              Text(
                "Cases: ${disease.caseCount}",
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: WeatherColorHelper.getIntensityColor(disease.intensity),
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
  }
}

/// Nearby diseases section widget
class NearbyDiseasesSection extends StatelessWidget {
  final bool isLoading;
  final List<DiseasePoint> diseases;

  const NearbyDiseasesSection({
    super.key,
    required this.isLoading,
    required this.diseases,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.green.shade600),
        ),
      );
    }

    if (diseases.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            "No disease reports found in your area",
            style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Nearby Disease Reports (100km radius)",
            style: TextStyle(
              color: Colors.green.shade800,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: diseases.length,
            itemBuilder: (context, index) {
              return DiseaseCardWidget(disease: diseases[index]);
            },
          ),
        ],
      ),
    );
  }
}
