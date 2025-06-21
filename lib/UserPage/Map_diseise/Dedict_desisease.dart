import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'map_model.dart';
import 'map_service.dart';

class HeatmapPageMap extends StatefulWidget {
  final LatLng? initialLocation;
  final DiseasePoint? selectedDisease;

  const HeatmapPageMap({Key? key, this.initialLocation, this.selectedDisease})
    : super(key: key);

  @override
  State<HeatmapPageMap> createState() => _HeatmapPageStateMap();
}

class _HeatmapPageStateMap extends State<HeatmapPageMap> {
  final DiseasePointService _service = DiseasePointService();
  MapController? _mapController;
  bool _isLoading = true;

  // Place name state variable
  String _currentPlaceName = "";
  LatLng? _currentLocation;
  List<DiseasePoint> _diseasePoints = [];

  // Simplified filter options
  bool _showPlantDiseases =
      true; // true for plant diseases, false for animal diseases
  DateTime _selectedDate = DateTime.now();

  late Size _screenSize;
  Offset? _cardPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    // Set the filter based on selected disease type if available
    if (widget.selectedDisease != null) {
      _showPlantDiseases = widget.selectedDisease!.isPlantDisease;
    }
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() => _isLoading = true);

      if (widget.initialLocation != null) {
        setState(() {
          _currentLocation = widget.initialLocation;
          if (widget.selectedDisease != null) {
            _diseasePoints = [widget.selectedDisease!];
          }
        });
      }

      await _getCurrentLocation();
      await _fetchDiseasePoints(); // Fetch points after location is set

      setState(() => _isLoading = false);

      // Wait for the map to be built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_mapController != null && _currentLocation != null) {
          _mapController!.move(_currentLocation!, 13.0);
          if (widget.selectedDisease != null) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _showPointDetails(context, widget.selectedDisease!);
              }
            });
          }
        }
      });
    } catch (e) {
      print('Error initializing map: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading map: $e')));
      }
    }
  }

  void _initializeCardPosition() {
    _screenSize = MediaQuery.of(context).size;
    setState(() {
      _cardPosition = Offset(
        _screenSize.width - 200, // Position from right
        _screenSize.height - 200, // Position from bottom
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get place name
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          _currentPlaceName =
              "${placemarks.first.locality}, ${placemarks.first.administrativeArea}";
        }
        _isLoading = false;
      });

      // Move map to current location after state is updated
      if (_currentLocation != null) {
        // Add a small delay to ensure the map is ready
        await Future.delayed(const Duration(milliseconds: 100));
        _mapController!.move(_currentLocation!, 13.0);
        _fetchDiseasePoints();
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  Future<void> _fetchDiseasePoints() async {
    setState(() => _isLoading = true);

    try {
      print(
        'Fetching all disease points for: ${_showPlantDiseases ? 'Plants' : 'Animals'}',
      ); // Debug log
      final points = await _service.getAllDiseasePoints(
        isPlantDisease: _showPlantDiseases,
        startDate: DateTime(_selectedDate.year, _selectedDate.month, 1),
        endDate: DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
      );

      print('Fetched ${points.length} points'); // Debug log

      if (mounted) {
        setState(() {
          _diseasePoints = points;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching disease points: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching disease points: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Disease Heatmap'),
        backgroundColor: Colors.green[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'Loading map data...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildFilterBar(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPlaceName.isEmpty
                              ? 'Loading location...'
                              : _currentPlaceName,
                          style: TextStyle(fontWeight: FontWeight.bold),
                          overflow:
                              TextOverflow.ellipsis, // Add overflow handling
                        ),
                      ),
                      const Spacer(),
                      _buildZoneLegend(),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      if (_currentLocation != null) // Changed condition
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentLocation!,
                            initialZoom: 13.0,
                            onMapReady: () {
                              if (_mapController != null &&
                                  _currentLocation != null) {
                                _mapController!.move(_currentLocation!, 13.0);
                                // Trigger a fetch of disease points when map is ready
                                _fetchDiseasePoints();
                              }
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                            ),
                            // Show circle markers for zones
                            CircleLayer(circles: _getCircleMarkers()),
                            // Show the markers on top of the circles
                            MarkerLayer(
                              markers: _diseasePoints
                                  .where(
                                    (point) =>
                                        point.isPlantDisease ==
                                            _showPlantDiseases &&
                                        point.reportDate.year ==
                                            _selectedDate.year &&
                                        point.reportDate.month ==
                                            _selectedDate.month,
                                  )
                                  .map(
                                    (point) => Marker(
                                      point: point.location,
                                      width: 60.0,
                                      height: 60.0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showPointDetails(context, point),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _getMarkerColor(
                                                  point.caseCount,
                                                ).withOpacity(0.9),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 3,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                point.isPlantDisease
                                                    ? Icons.local_florist
                                                    : Icons.pets,
                                                color: Colors.white,
                                                size: 20.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            if (_currentLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _currentLocation!,
                                    width: 40.0,
                                    height: 40.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.my_location,
                                        color: Colors.white,
                                        size: 24.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: _diseasePoints
                                  .where(
                                    (point) =>
                                        point.isPlantDisease ==
                                            _showPlantDiseases &&
                                        point.reportDate.year ==
                                            _selectedDate.year &&
                                        point.reportDate.month ==
                                            _selectedDate.month,
                                  )
                                  .map(
                                    (point) => Marker(
                                      point: point.location,
                                      width: 60.0,
                                      height: 60.0,
                                      child: GestureDetector(
                                        onTap: () =>
                                            _showPointDetails(context, point),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: _getMarkerColor(
                                                  point.caseCount,
                                                ).withOpacity(0.9),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 3,
                                                    offset: Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                point.isPlantDisease
                                                    ? Icons.local_florist
                                                    : Icons.pets,
                                                color: Colors.white,
                                                size: 20.0,
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${point.caseCount}',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                      if (_cardPosition !=
                          null) // Only show when position is set
                        Positioned(
                          left: _cardPosition!.dx,
                          top: _cardPosition!.dy,
                          child: Draggable(
                            feedback: _buildDraggableCard(isBeingDragged: true),
                            childWhenDragging:
                                Container(), // Empty container when dragging
                            child: _buildDraggableCard(isBeingDragged: false),
                            onDragEnd: (details) {
                              setState(() {
                                _cardPosition = _getBoundedPosition(
                                  details.offset,
                                );
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadDialog(context),
        backgroundColor: Colors.green[700],
        label: const Text('Report Disease'),
        icon: const Icon(Icons.add_location),
      ),
    );
  }

  Widget _buildZoneLegend() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Red Zone',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        SizedBox(width: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Yellow Zone',
            style: TextStyle(color: Colors.black, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // Update the circle markers based on new filters
  List<CircleMarker> _getCircleMarkers() {
    print('Total disease points: ${_diseasePoints.length}'); // Debug print
    final filteredPoints = _diseasePoints
        .where(
          (point) =>
              point.isPlantDisease == _showPlantDiseases &&
              point.reportDate.year == _selectedDate.year &&
              point.reportDate.month == _selectedDate.month,
        )
        .toList();

    print(
      'Filtered disease points for ${_selectedDate.year}/${_selectedDate.month} (Plant: $_showPlantDiseases): ${filteredPoints.length}',
    ); // Debug print

    return filteredPoints.map((point) {
      // Use the case count to determine zone color (red or yellow)
      Color circleColor = _getZoneColor(point.caseCount);

      // Fixed radius based on zone type
      double radius = point.caseCount >= 50
          ? 500.0
          : 300.0; // Increased radius for better visibility

      print(
        'Generating circle for point at ${point.location} with radius $radius and color $circleColor',
      ); // Debug print

      return CircleMarker(
        point: point.location,
        color: circleColor.withOpacity(0.2),
        borderColor: circleColor.withOpacity(0.7),
        borderStrokeWidth: 2.0,
        radius: radius,
      );
    }).toList();
  }

  // New method to determine zone color based on case count
  Color _getZoneColor(int caseCount) {
    // Red zone if cases >= 50, otherwise yellow zone
    return caseCount >= 50 ? Colors.red : Colors.amber;
  }

  // Updated to use case count instead of intensity
  Color _getMarkerColor(int caseCount) {
    return caseCount >= 50 ? Colors.red : Colors.amber;
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Plant Disease'),
                      icon: Icon(Icons.local_florist),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Animal Disease'),
                      icon: Icon(Icons.pets),
                    ),
                  ],
                  selected: {_showPlantDiseases},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _showPlantDiseases = newSelection.first;
                    });
                    // Fetch new disease points when filter changes
                    _fetchDiseasePoints();
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>((
                      Set<MaterialState> states,
                    ) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.green.shade100;
                      }
                      return Colors.transparent;
                    }),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: Colors.green.shade700,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null && picked != _selectedDate) {
                      setState(() {
                        _selectedDate = picked;
                      });
                      // Fetch new disease points when date changes
                      _fetchDiseasePoints();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 1,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableCard({required bool isBeingDragged}) {
    return Card(
      elevation: isBeingDragged ? 8 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 180, // Fixed width
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Disease Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Icon(Icons.drag_indicator, size: 16, color: Colors.grey),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text('Red Zone (50+ cases)'),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 4),
                Text('Yellow Zone (<50 cases)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Offset _getBoundedPosition(Offset position) {
    const cardWidth = 180.0;
    const cardHeight = 100.0;

    double dx = position.dx;
    double dy = position.dy;

    // Bound the position within the screen
    dx = dx.clamp(0, _screenSize.width - cardWidth);
    dy = dy.clamp(0, _screenSize.height - cardHeight);

    return Offset(dx, dy);
  }

  void _showUploadDialog(BuildContext context) {
    String diseaseName = '';
    String cropOrAnimalType = '';
    int caseCount = 1;
    String notes = '';
    LatLng? selectedLocation = _currentLocation;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            _showPlantDiseases
                ? 'Report Plant Disease'
                : 'Report Animal Disease',
            style: TextStyle(color: Colors.green[700]),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Disease Name',
                    hintText: _showPlantDiseases
                        ? 'e.g., Leaf Blight'
                        : 'e.g., Foot and Mouth',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.green.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) => diseaseName = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: _showPlantDiseases ? 'Crop Type' : 'Animal Type',
                    hintText: _showPlantDiseases
                        ? 'e.g., Rice'
                        : 'e.g., Cattle',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.green.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) => cropOrAnimalType = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Number of Cases',
                    hintText: 'Enter number of affected plants/animals',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.green.shade700,
                        width: 2,
                      ),
                    ),
                    helperText: 'Cases ≥ 50 will be marked as Red Zone',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => caseCount = int.tryParse(value) ?? 1,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any additional information',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.green.shade700,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 3,
                  onChanged: (value) => notes = value,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    await _getCurrentLocation();
                    selectedLocation = _currentLocation;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Current location set'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Submit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
              ),
              onPressed: () async {
                if (diseaseName.isEmpty ||
                    cropOrAnimalType.isEmpty ||
                    selectedLocation == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                    ),
                  );
                  return;
                }

                try {
                  final newPoint = await _service.createDiseasePoint(
                    latitude: selectedLocation!.latitude,
                    longitude: selectedLocation!.longitude,
                    diseaseName: diseaseName,
                    cropType: cropOrAnimalType,
                    intensity: caseCount >= 50 ? 0.9 : caseCount / 60.0,
                    caseCount: caseCount,
                    placeName: _currentPlaceName,
                    isPlantDisease: _showPlantDiseases,
                    notes: notes,
                  );

                  setState(() {
                    _diseasePoints.add(newPoint);
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Disease report submitted successfully'),
                        ],
                      ),
                      backgroundColor: caseCount >= 50
                          ? Colors.red
                          : Colors.amber,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating disease point: $e')),
                  );
                }
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }

  // Enhanced disease point details with improved UI
  void _showPointDetails(BuildContext context, DiseasePoint point) {
    final bool isRedZone = point.caseCount >= 50;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isRedZone ? Colors.red : Colors.amber,
                shape: BoxShape.circle,
              ),
              child: Icon(
                point.isPlantDisease ? Icons.local_florist : Icons.pets,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    point.diseaseName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    isRedZone ? 'RED ZONE' : 'YELLOW ZONE',
                    style: TextStyle(
                      color: isRedZone ? Colors.red : Colors.amber.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text('Location: ${point.placeName}')),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Icon(
                          point.isPlantDisease ? Icons.grass : Icons.pets,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        SizedBox(width: 8),
                        Text(
                          point.isPlantDisease
                              ? 'Crop: ${point.cropType}'
                              : 'Animal: ${point.cropType}',
                        ),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: isRedZone ? Colors.red : Colors.amber,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cases: ${point.caseCount}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRedZone
                                ? Colors.red
                                : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                    Divider(),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Report Date: ${point.reportDate.day}/${point.reportDate.month}/${point.reportDate.year}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (point.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(point.notes),
            ],
            SizedBox(height: 16),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isRedZone ? Colors.red.shade50 : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRedZone ? Colors.red : Colors.amber,
                    width: 1,
                  ),
                ),
                child: Text(
                  isRedZone
                      ? 'High Risk Area - Take Precautions'
                      : 'Moderate Risk Area - Monitor Situation',
                  style: TextStyle(
                    color: isRedZone
                        ? Colors.red.shade900
                        : Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.share),
            label: Text('Share'),
            onPressed: () {
              // Simplified share logic without the ID check since it's not available
              // TODO: Implement sharing logic with the point data directly
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing disease information...')),
              );
            },
          ),
          ElevatedButton(
            child: const Text('Close'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.green[700]),
            SizedBox(width: 8),
            Text('Disease Zone Information'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.red.shade50,
              margin: EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            "R",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'RED ZONE (50+ cases)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About Disease Zones',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Disease zones are determined by the number of reported cases:',
                            style: TextStyle(fontSize: 14),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Red Zone: 50 or more cases\n• Yellow Zone: Less than 50 cases',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
