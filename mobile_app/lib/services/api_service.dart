import '../shared/models/user_model.dart';
import '../shared/models/hospital_model.dart';
import '../shared/models/reservation_model.dart';

class ApiService {
  // Mock fallback dataset for hackathon offline or real backend server testing
  static final List<HospitalModel> mockHospitals = [
    HospitalModel(
      id: 'hosp-01',
      name: 'Shaukat Khanum Memorial Hospital',
      bloodBankName: 'Shaukat Khanum Blood Bank',
      address: '7A Block R-3, Johar Town',
      city: 'Lahore',
      phone: '+92 42 35905000',
      emergencyContact: '+92 42 111 155 555',
      workingHours: '24/7 Open',
      distanceKm: 1.8,
      latitude: 31.4697,
      longitude: 74.2728,
      bloodInventory: {
        'A+': 18, 'A-': 4, 'B+': 22, 'B-': 6,
        'AB+': 9, 'AB-': 2, 'O+': 35, 'O-': 8
      },
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=600',
    ),
    HospitalModel(
      id: 'hosp-02',
      name: 'Doctors Hospital & Medical Center',
      bloodBankName: 'Doctors Hospital Regional Blood Center',
      address: '152-G/1, Canal Bank Road, Johar Town',
      city: 'Lahore',
      phone: '+92 42 35302701',
      emergencyContact: '+92 42 35302710',
      workingHours: '24 Hours Emergency Service',
      distanceKm: 3.2,
      latitude: 31.4789,
      longitude: 74.2831,
      bloodInventory: {
        'A+': 12, 'A-': 1, 'B+': 15, 'B-': 0,
        'AB+': 4, 'AB-': 1, 'O+': 19, 'O-': 5
      },
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=600',
    ),
    HospitalModel(
      id: 'hosp-03',
      name: 'Services Hospital Lahore',
      bloodBankName: 'Services Central Blood Bank',
      address: 'Ghaus-ul-Azam Road, Shadman',
      city: 'Lahore',
      phone: '+92 42 99203402',
      emergencyContact: '+92 42 99203400',
      workingHours: '24/7 Open',
      distanceKm: 5.5,
      latitude: 31.5422,
      longitude: 74.3315,
      bloodInventory: {
        'A+': 30, 'A-': 8, 'B+': 40, 'B-': 10,
        'AB+': 15, 'AB-': 4, 'O+': 50, 'O-': 12
      },
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1516549655169-df83a0774514?w=600',
    ),
    HospitalModel(
      id: 'hosp-04',
      name: 'Jinnah Hospital Lahore',
      bloodBankName: 'Jinnah Emergency Blood Bank',
      address: 'Usman Block, Garden Town',
      city: 'Lahore',
      phone: '+92 42 99231400',
      emergencyContact: '+92 42 99231405',
      workingHours: '24 Hours Emergency',
      distanceKm: 4.1,
      latitude: 31.4925,
      longitude: 74.3012,
      bloodInventory: {
        'A+': 25, 'A-': 5, 'B+': 30, 'B-': 7,
        'AB+': 10, 'AB-': 3, 'O+': 45, 'O-': 9
      },
      isAvailable: true,
      imageUrl: 'https://images.unsplash.com/photo-1538108149393-fbbd81895907?w=600',
    ),
  ];

  static Future<UserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return const UserModel(
      id: 'user-77',
      fullName: 'Mueeza Khan',
      email: 'mueeza.patient@lifelynk.ai',
      phone: '+92 300 1234567',
      bloodGroup: 'O+',
      address: 'Johar Town, Block H3, Lahore',
    );
  }

  static Future<UserModel> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String bloodGroup,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return UserModel(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      email: email,
      phone: phone,
      bloodGroup: bloodGroup,
      address: 'Lahore, Pakistan',
    );
  }

  static Future<List<HospitalModel>> searchBlood({
    required String bloodGroup,
    required String city,
    String? hospitalName,
    double maxDistanceKm = 50.0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return mockHospitals.where((h) {
      final matchesGroup = (h.bloodInventory[bloodGroup] ?? 0) > 0;
      final matchesCity = city.isEmpty || h.city.toLowerCase() == city.toLowerCase();
      final matchesName = hospitalName == null || hospitalName.isEmpty || h.name.toLowerCase().contains(hospitalName.toLowerCase());
      return matchesGroup && matchesCity && matchesName;
    }).toList();
  }

  static Future<ReservationModel> createReservation({
    required String patientName,
    required String hospitalName,
    required String hospitalAddress,
    required String bloodGroup,
    required int units,
    required DateTime date,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final ref = 'LL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    return ReservationModel(
      id: 'res-${DateTime.now().millisecondsSinceEpoch}',
      patientName: patientName,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      bloodGroup: bloodGroup,
      unitsRequired: units,
      date: date,
      status: ReservationStatus.pending,
      referenceCode: ref,
    );
  }

}
