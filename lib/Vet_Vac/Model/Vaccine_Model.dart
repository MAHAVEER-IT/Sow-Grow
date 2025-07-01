class Vaccination {
  final String id;
  final String name;
  final DateTime dueDate;
  final String notes;
  final bool isRecurring;
  final bool reminderSent;

  Vaccination({
    required this.id,
    required this.name,
    required this.dueDate,
    this.notes = '',
    this.isRecurring = false,
    this.reminderSent = false,
  });

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      id: json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? '',
      dueDate: json['dueDate'] != null
          ? DateTime.parse(json['dueDate'])
          : DateTime.now(),
      notes: json['notes']?.toString() ?? '',
      isRecurring: json['isRecurring'] ?? false,
      reminderSent: json['reminderSent'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dueDate': dueDate.toIso8601String(),
      'notes': notes,
      'isRecurring': isRecurring,
      'reminderSent': reminderSent,
    };
  }
}

class Pet {
  final String id;
  final String name;
  final String type;
  final String breed;
  final DateTime birthDate;
  final String vetName;
  final String vetPhone;
  final List<Vaccination> vaccinations;

  Pet({
    required this.id,
    required this.name,
    required this.type,
    required this.breed,
    required this.birthDate,
    required this.vetName,
    required this.vetPhone,
    required this.vaccinations,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['petId'] ?? json['id'],
      name: json['name'],
      type: json['type'],
      breed: json['breed'],
      birthDate: DateTime.parse(json['birthDate']),
      vetName: json['vetName'] ?? '',
      vetPhone: json['vetPhone'] ?? '',
      vaccinations: (json['vaccinations'] as List?)
              ?.map((v) => Vaccination.fromJson(v))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'breed': breed,
      'birthDate': birthDate.toIso8601String(),
      'vetName': vetName,
      'vetPhone': vetPhone,
      'vaccinations': vaccinations.map((v) => v.toJson()).toList(),
    };
  }
}
