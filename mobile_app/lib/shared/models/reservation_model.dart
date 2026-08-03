enum ReservationStatus { pending, approved, rejected, cancelled }

class ReservationModel {
  final String id;
  final String patientName;
  final String hospitalName;
  final String hospitalAddress;
  final String bloodGroup;
  final int unitsRequired;
  final DateTime date;
  final ReservationStatus status;
  final String referenceCode;

  const ReservationModel({
    required this.id,
    required this.patientName,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.bloodGroup,
    required this.unitsRequired,
    required this.date,
    required this.status,
    required this.referenceCode,
  });

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: json['id'] ?? '',
      patientName: json['patient_name'] ?? '',
      hospitalName: json['hospital_name'] ?? '',
      hospitalAddress: json['hospital_address'] ?? '',
      bloodGroup: json['blood_group'] ?? 'O+',
      unitsRequired: json['units_required'] ?? 1,
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      status: ReservationStatus.values.firstWhere(
        (e) => e.name == (json['status'] ?? 'pending'),
        orElse: () => ReservationStatus.pending,
      ),
      referenceCode: json['reference_code'] ?? 'LL-98210',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_name': patientName,
      'hospital_name': hospitalName,
      'hospital_address': hospitalAddress,
      'blood_group': bloodGroup,
      'units_required': unitsRequired,
      'date': date.toIso8601String(),
      'status': status.name,
      'reference_code': referenceCode,
    };
  }
}
