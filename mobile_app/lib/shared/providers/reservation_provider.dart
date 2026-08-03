import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation_model.dart';
import '../../services/api_service.dart';

class ReservationState {
  final List<ReservationModel> reservations;
  final bool isLoading;
  final ReservationModel? lastCreatedReservation;

  ReservationState({
    List<ReservationModel>? reservations,
    this.isLoading = false,
    this.lastCreatedReservation,
  }) : reservations = reservations ?? [
          ReservationModel(
            id: 'res-101',
            patientName: 'Mueeza Khan',
            hospitalName: 'Shaukat Khanum Memorial Hospital',
            hospitalAddress: 'Johar Town, Lahore',
            bloodGroup: 'O+',
            unitsRequired: 2,
            date: DateTime.utc(2026, 8, 1),
            status: ReservationStatus.approved,
            referenceCode: 'LL-88219',
          ),
          ReservationModel(
            id: 'res-102',
            patientName: 'Mueeza Khan',
            hospitalName: 'Services Hospital Lahore',
            hospitalAddress: 'Shadman, Lahore',
            bloodGroup: 'O+',
            unitsRequired: 1,
            date: DateTime.utc(2026, 7, 25),
            status: ReservationStatus.pending,
            referenceCode: 'LL-74102',
          ),
        ];

  ReservationState copyWith({
    List<ReservationModel>? reservations,
    bool? isLoading,
    ReservationModel? lastCreatedReservation,
  }) {
    return ReservationState(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      lastCreatedReservation: lastCreatedReservation ?? this.lastCreatedReservation,
    );
  }
}

class ReservationNotifier extends Notifier<ReservationState> {
  @override
  ReservationState build() {
    return ReservationState();
  }

  Future<ReservationModel?> createReservation({
    required String patientName,
    required String hospitalName,
    required String hospitalAddress,
    required String bloodGroup,
    required int units,
    required DateTime date,
  }) async {
    state = state.copyWith(isLoading: true);
    final reservation = await ApiService.createReservation(
      patientName: patientName,
      hospitalName: hospitalName,
      hospitalAddress: hospitalAddress,
      bloodGroup: bloodGroup,
      units: units,
      date: date,
    );
    final updatedList = [reservation, ...state.reservations];
    state = state.copyWith(
      isLoading: false,
      reservations: updatedList,
      lastCreatedReservation: reservation,
    );
    return reservation;
  }
}

final reservationProvider = NotifierProvider<ReservationNotifier, ReservationState>(ReservationNotifier.new);
