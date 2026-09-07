import 'user_model.dart';
import 'patient_model.dart';

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final PatientModel patient;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.patient,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      user: UserModel.fromJson(json['user']),
      patient: PatientModel.fromJson(json['patient']),
    );
  }
}