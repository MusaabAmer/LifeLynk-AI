class BloodInventoryModel {
  final String bloodGroup;
  final String bloodGroupId;
  final String bloodGroupCode;
  final String? bloodGroupName;

  final int totalUnits;
  final int availableUnits;
  final int reservedUnits;

  final String? donationDate;
  final String? expiryDate;
  final String? storageLocation;
  final String? status;

  const BloodInventoryModel({
    required this.bloodGroup,
    required this.bloodGroupId,
    required this.bloodGroupCode,
    this.bloodGroupName,
    this.totalUnits = 0,
    required this.availableUnits,
    this.reservedUnits = 0,
    this.donationDate,
    this.expiryDate,
    this.storageLocation,
    this.status,
  });

  factory BloodInventoryModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final code =
        json['blood_group_code']?.toString() ??
        json['blood_group']?.toString() ??
        '';

    return BloodInventoryModel(
      bloodGroup: code,

      bloodGroupId:
          json['blood_group_id']?.toString() ?? '',

      bloodGroupCode: code,

      bloodGroupName:
          json['blood_group_name']?.toString(),

      totalUnits:
          (json['total_units'] as num?)?.toInt() ?? 0,

      availableUnits:
          (json['available_units'] as num?)?.toInt() ?? 0,

      reservedUnits:
          (json['reserved_units'] as num?)?.toInt() ?? 0,

      donationDate:
          json['donation_date']?.toString(),

      expiryDate:
          json['expiry_date']?.toString(),

      storageLocation:
          json['storage_location']?.toString(),

      status:
          json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blood_group': bloodGroup,
      'blood_group_id': bloodGroupId,
      'blood_group_code': bloodGroupCode,
      'blood_group_name': bloodGroupName,
      'total_units': totalUnits,
      'available_units': availableUnits,
      'reserved_units': reservedUnits,
      'donation_date': donationDate,
      'expiry_date': expiryDate,
      'storage_location': storageLocation,
      'status': status,
    };
  }
}