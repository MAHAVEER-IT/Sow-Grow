import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sow_and_grow/UserPage/Vet_Vac/pet_service.dart';

import 'Vaccine_Model.dart';
import 'add_new_pet_page.dart';

class PetVaccinationApp extends StatelessWidget {
  const PetVaccinationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Livestocare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          primary: Colors.teal.shade700,
          secondary: Colors.amber.shade600,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late List<Pet> pets = [];
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadPets();
    _fabAnimationController.forward();
  }

  static const platform = MethodChannel('com.example.sms/send');

  Future<bool> sendSMS(String phone, String message) async {
    try {
      await platform.invokeMethod('sendSMS', {
        'phone': phone,
        'message': message,
      });
      print("SMS sent");
      return true;
    } on PlatformException catch (e) {
      print("Error: ${e.message}");
      return false;
    }
  }

  final PetService _petService = PetService();

  Future<void> _loadPets() async {
    try {
      final fetchedPets = await _petService.getPets();
      setState(() {
        pets = fetchedPets;
      });
      _checkUpcomingVaccinations();
    } catch (e) {
      print('Error loading pets: $e');
      // Handle error state
    }
  }

  Future<void> _savePets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'pets',
      pets.map((pet) => jsonEncode(pet.toJson())).toList(),
    );
  }

  void _checkUpcomingVaccinations() {
    final now = DateTime.now();
    bool updated = false;

    for (var pet in pets) {
      List<Vaccination> toAdd = [];
      for (var vaccine in pet.vaccinations) {
        // Schedule notification
        if (vaccine.dueDate.isAfter(now)) {}

        // Handle recurring vaccines
        if (vaccine.isRecurring && vaccine.dueDate.isBefore(now)) {
          DateTime nextDate = vaccine.dueDate;
          while (nextDate.isBefore(now)) {
            nextDate = nextDate.add(const Duration(days: 28));
          }
          toAdd.add(
            Vaccination(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: vaccine.name,
              dueDate: nextDate,
              notes: vaccine.notes,
              isRecurring: true,
            ),
          );
          updated = true;
        }
      }
      pet.vaccinations.addAll(toAdd);
    }

    if (updated) _savePets();
  }

  void _addNewPet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPetScreen(
          onPetAdded: (newPet) async {
            final savedPet = await _petService.createPet(newPet);
            if (savedPet != null) {
              setState(() {
                pets.add(savedPet);
              });
            }
          },
        ),
      ),
    );
    _loadPets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livestocare'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () => _showNotificationsSettings(context),
          ),
        ],
      ),
      body: pets.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _PetCard(
                pet: pets[index],
                onTap: () => _navigateToDetail(pets[index]),
                onDelete: () => _deletePet(index),
              ),
            ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimationController,
          curve: Curves.fastOutSlowIn,
        ),
        child: FloatingActionButton.extended(
          onPressed: _addNewPet,
          icon: const Icon(Icons.pets),
          label: const Text('Add Cattle'),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('images/cattle.png', width: 200),
          const SizedBox(height: 20),
          Text(
            'No Cattles Added Yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text('Start by adding your furry friend!'),
        ],
      ),
    );
  }

  void _navigateToDetail(Pet pet) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PetDetailScreen(
          pet: pet,
          onUpdate: (updatedPet) async {
            final savedPet = await _petService.updatePet(updatedPet);
            if (savedPet != null) {
              setState(() {
                final index = pets.indexWhere((p) => p.id == updatedPet.id);
                if (index != -1) {
                  pets[index] = savedPet;
                }
              });
            }
          },
          onDelete: () => Navigator.pop(context),
          sendSMS: sendSMS,
        ),
      ),
    );
  }

  void _deletePet(int index) async {
    final petToDelete = pets[index];
    final success = await _petService.deletePet(petToDelete.id);

    if (success) {
      setState(() {
        pets.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pet deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete pet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showNotificationsSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Settings'),
        content: const Text('Configure your notification preferences...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  final Pet pet;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PetCard({
    required this.pet,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge(pet.birthDate);
    final nextVaccine =
        pet.vaccinations
            .where((v) => v.dueDate.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade100, Colors.teal.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _PetAvatar(type: pet.type),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pet.name, style: Theme.of(context).textTheme.titleLarge),
                  Text('${pet.type} • ${pet.breed}'),
                  Text('Age: $age'),
                  if (nextVaccine.isNotEmpty)
                    Text(
                      'Next: ${nextVaccine.first.name} - ${DateFormat.MMMd().format(nextVaccine.first.dueDate)}',
                      style: TextStyle(color: Colors.teal.shade700),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red.shade300),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    if (months < 0) {
      years--;
      months += 12;
    }
    return years > 0 ? '$years years' : '$months months';
  }
}

class _PetAvatar extends StatelessWidget {
  final String type;
  final double size;

  const _PetAvatar({required this.type, this.size = 56});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type.toLowerCase()) {
      case 'cow':
        icon = Icons.pets;
        break;
      case 'goat':
        icon = Icons.pets;
        break;
      case 'chicken':
        icon = Icons.pets;
        break;
      default:
        icon = Icons.help_outline;
    }

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Colors.teal.shade100,
      child: Icon(icon, size: size * 0.6, color: Colors.teal.shade700),
    );
  }
}

class PetDetailScreen extends StatefulWidget {
  final Pet pet;
  final Function(Pet) onUpdate;
  final VoidCallback onDelete;
  final Future<bool> Function(String, String) sendSMS;

  const PetDetailScreen({
    super.key,
    required this.pet,
    required this.onUpdate,
    required this.onDelete,
    required this.sendSMS,
  });

  @override
  State<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends State<PetDetailScreen> {
  late Pet pet;
  final PetService _petService = PetService();

  @override
  void initState() {
    super.initState();
    pet = widget.pet;
  }

  @override
  Widget build(BuildContext context) {
    final upcomingVaccines =
        pet.vaccinations
            .where((v) => v.dueDate.isAfter(DateTime.now()))
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final pastVaccines =
        pet.vaccinations
            .where((v) => v.dueDate.isBefore(DateTime.now()))
            .toList()
          ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: Text(
          pet.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _editPetProfile,
            tooltip: 'Edit Profile',
          ),
        ],
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _PetProfileHeader(pet: pet)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionTitle(
                  'Upcoming Vaccinations',
                  Icons.event_available,
                ),
                ...(_buildVaccineList(upcomingVaccines)),
                const SizedBox(height: 8),
                _buildSectionTitle('Vaccination History', Icons.history),
                ...(_buildVaccineList(pastVaccines, isPast: true)),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVaccination,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        label: const Text('Add Vaccination'),
        icon: const Icon(Icons.add),
        elevation: 4,
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVaccineList(
    List<Vaccination> vaccines, {
    bool isPast = false,
  }) {
    if (vaccines.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade500, size: 28),
              const SizedBox(width: 16),
              Text(
                'No vaccinations found',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
            ],
          ),
        ),
      ];
    }

    return vaccines
        .map(
          (vaccine) => _VaccineCard(
            vaccine: vaccine,
            isPast: isPast,
            onDelete: () => _deleteVaccination(vaccine),
          ),
        )
        .toList();
  }

  void _addVaccination() {
    showDialog(
      context: context,
      builder: (context) => VaccineDialog(
        onSave: (newVaccine) async {
          final updatedPet = await _petService.addVaccination(
            pet.id,
            newVaccine,
          );
          if (updatedPet != null) {
            setState(() {
              pet = updatedPet;
            });
            widget.onUpdate(pet);

            if (pet.vetPhone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Veterinarian phone number is missing. SMS not sent.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            final message =
                'New vaccination scheduled for ${pet.name}: '
                '${newVaccine.name} due on ${DateFormat.yMMMd().format(newVaccine.dueDate)}. '
                'Notes: ${newVaccine.notes.isNotEmpty ? newVaccine.notes : "None"}';

            final success = await widget.sendSMS(pet.vetPhone, message);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'SMS reminder sent to veterinarian!'
                      : 'Failed to send SMS reminder',
                ),
                backgroundColor: success
                    ? Colors.green.shade600
                    : Colors.red.shade600,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _deleteVaccination(Vaccination vaccine) async {
    final updatedPet = await _petService.deleteVaccination(pet.id, vaccine.id);
    if (updatedPet != null) {
      setState(() {
        pet = updatedPet;
      });
      widget.onUpdate(pet);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vaccination deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete vaccination'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editPetProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit, color: Theme.of(context).primaryColor),
            const SizedBox(width: 10),
            const Text('Edit Pet Profile'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: pet.name),
                decoration: InputDecoration(
                  labelText: 'Pet Name',
                  icon: const Icon(Icons.pets),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (value) => setState(() {
                  pet = Pet(
                    id: pet.id,
                    name: value,
                    type: pet.type,
                    breed: pet.breed,
                    birthDate: pet.birthDate,
                    vetName: pet.vetName,
                    vetPhone: pet.vetPhone,
                    vaccinations: pet.vaccinations,
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: pet.breed),
                decoration: InputDecoration(
                  labelText: 'Breed',
                  icon: const Icon(Icons.category),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (value) => setState(() {
                  pet = Pet(
                    id: pet.id,
                    name: pet.name,
                    type: pet.type,
                    breed: value,
                    birthDate: pet.birthDate,
                    vetName: pet.vetName,
                    vetPhone: pet.vetPhone,
                    vaccinations: pet.vaccinations,
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: pet.vetName),
                decoration: InputDecoration(
                  labelText: 'Vet Name',
                  icon: const Icon(Icons.medical_services),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                onChanged: (value) => setState(() {
                  pet = Pet(
                    id: pet.id,
                    name: pet.name,
                    type: pet.type,
                    breed: pet.breed,
                    birthDate: pet.birthDate,
                    vetName: value,
                    vetPhone: pet.vetPhone,
                    vaccinations: pet.vaccinations,
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: TextEditingController(text: pet.vetPhone),
                decoration: InputDecoration(
                  labelText: 'Vet Phone',
                  icon: const Icon(Icons.phone),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) => setState(() {
                  pet = Pet(
                    id: pet.id,
                    name: pet.name,
                    type: pet.type,
                    breed: pet.breed,
                    birthDate: pet.birthDate,
                    vetName: pet.vetName,
                    vetPhone: value,
                    vaccinations: pet.vaccinations,
                  );
                }),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedPet = await _petService.updatePet(pet);
              if (updatedPet != null) {
                setState(() {
                  pet = updatedPet;
                });
                widget.onUpdate(pet);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _PetProfileHeader extends StatelessWidget {
  final Pet pet;

  const _PetProfileHeader({required this.pet});

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge(pet.birthDate);

    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Hero(
            tag: 'pet-${pet.id}',
            child: _PetAvatar(type: pet.type),
          ),
          const SizedBox(height: 16),
          Text(
            pet.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pet.breed} • $age old',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildInfoChip(
                context,
                'Veterinarian',
                pet.vetName,
                Icons.medical_services,
              ),
              const SizedBox(width: 16),
              _buildInfoChip(context, 'Phone', pet.vetPhone, Icons.phone),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                value.isEmpty ? 'Not set' : value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    return years > 0 ? '$years years' : '$months months';
  }
}

class VaccineDialog extends StatefulWidget {
  final Function(Vaccination) onSave;

  const VaccineDialog({super.key, required this.onSave});

  @override
  State<VaccineDialog> createState() => _VaccineDialogState();
}

class _VaccineDialogState extends State<VaccineDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isRecurring = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.vaccines, color: Theme.of(context).primaryColor),
          const SizedBox(width: 10),
          const Text('Add Vaccination'),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Vaccine Name',
                icon: const Icon(Icons.medical_services),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Theme.of(context).primaryColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) setState(() => _dueDate = date);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Due Date',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        Text(
                          DateFormat.yMMMd().format(_dueDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text('Recurring (every 28 days)'),
                value: _isRecurring,
                onChanged: (value) => setState(() => _isRecurring = value),
                contentPadding: EdgeInsets.zero,
                activeColor: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes',
                icon: const Icon(Icons.notes),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a vaccine name'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            final newVaccine = Vaccination(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: _nameController.text,
              dueDate: _dueDate,
              notes: _notesController.text,
              isRecurring: _isRecurring,
            );
            widget.onSave(newVaccine);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _VaccineCard extends StatelessWidget {
  final Vaccination vaccine;
  final bool isPast;
  final VoidCallback onDelete;

  const _VaccineCard({
    required this.vaccine,
    required this.isPast,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final daysUntil = vaccine.dueDate.difference(DateTime.now()).inDays;
    final bool isUrgent = !isPast && daysUntil <= 7;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: _getCardColor(context, isPast, isUrgent),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getIconBgColor(context, isPast, isUrgent),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIcon(isPast, isUrgent),
            color: _getIconColor(isPast, isUrgent),
            size: 28,
          ),
        ),
        title: Text(
          vaccine.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isPast ? Colors.grey.shade700 : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event,
                  size: 14,
                  color: isPast ? Colors.grey.shade500 : Colors.black54,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMMMd().format(vaccine.dueDate),
                  style: TextStyle(
                    color: isPast ? Colors.grey.shade500 : Colors.black54,
                  ),
                ),
                if (!isPast && daysUntil >= 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getChipColor(isUrgent),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      daysUntil == 0
                          ? 'Today'
                          : daysUntil == 1
                          ? 'Tomorrow'
                          : 'In $daysUntil days',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _getChipTextColor(isUrgent),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (vaccine.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.notes,
                    size: 14,
                    color: isPast ? Colors.grey.shade500 : Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      vaccine.notes,
                      style: TextStyle(
                        color: isPast ? Colors.grey.shade500 : Colors.black54,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (vaccine.isRecurring) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.repeat, size: 14, color: Colors.indigo.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Recurring (28 days)',
                    style: TextStyle(
                      color: Colors.indigo.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red.shade400,
          onPressed: onDelete,
          tooltip: 'Delete vaccination',
        ),
      ),
    );
  }

  Color _getCardColor(BuildContext context, bool isPast, bool isUrgent) {
    if (isPast) return Colors.grey.shade100;
    if (isUrgent) return Colors.red.shade50;
    return Colors.white;
  }

  Color _getIconBgColor(BuildContext context, bool isPast, bool isUrgent) {
    if (isPast) return Colors.grey.shade200;
    if (isUrgent) return Colors.red.shade100;
    return Colors.blue.shade50;
  }

  IconData _getIcon(bool isPast, bool isUrgent) {
    if (isPast) return Icons.check_circle_outline;
    if (isUrgent) return Icons.notification_important;
    return Icons.event_available;
  }

  Color _getIconColor(bool isPast, bool isUrgent) {
    if (isPast) return Colors.green.shade600;
    if (isUrgent) return Colors.red.shade600;
    return Colors.blue.shade600;
  }

  Color _getChipColor(bool isUrgent) {
    if (isUrgent) return Colors.red.shade100;
    return Colors.blue.shade100;
  }

  Color _getChipTextColor(bool isUrgent) {
    if (isUrgent) return Colors.red.shade800;
    return Colors.blue.shade800;
  }
}
