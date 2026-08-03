class HospitalModel {
  final String id;
  final String name;
  final String bloodBankName;
  final String address;
  final String city;
  final String phone;
  final String emergencyContact;
  final String workingHours;
  final double distanceKm;
  final double latitude;
  final double longitude;
  final Map<String, int> bloodInventory; // e.g. {'A+': 12, 'O-': 4}
  final bool isAvailable;
  final String imageUrl;

  const HospitalModel({
    required this.id,
    required this.name,
    required this.bloodBankName,
    required this.address,
    required this.city,
    required this.phone,
    required this.emergencyContact,
    required this.workingHours,
    required this.distanceKm,
    required this.latitude,
    required this.longitude,
    required this.bloodInventory,
    required this.isAvailable,
    required this.imageUrl,
  });

  factory HospitalModel.fromJson(Map<String, dynamic> json) {
    return HospitalModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bloodBankName: json['blood_bank_name'] ?? json['name'] ?? '',
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      phone: json['phone'] ?? '',
      emergencyContact: json['emergency_contact'] ?? json['phone'] ?? '',
      workingHours: json['working_hours'] ?? '24/7 Open',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 2.5,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 31.5204,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 74.3587,
      bloodInventory: Map<String, int>.from(json['blood_inventory'] ?? {
        'A+': 8, 'A-': 2, 'B+': 14, 'B-': 3,
        'AB+': 5, 'AB-': 1, 'O+': 20, 'O-': 6
      }),
      isAvailable: json['is_available'] ?? true,
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=500',
    );
  }
}
