import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/reservation_model.dart';
import '../../shared/providers/reservation_provider.dart';
import '../../shared/widgets/reservation_card.dart';

class ReservationHistoryScreen extends ConsumerWidget {
  const ReservationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationState = ref.watch(reservationProvider);
    final allReservations = reservationState.reservations;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reservation History'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Approved'),
              Tab(text: 'Pending'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReservationList(allReservations),
            _buildReservationList(allReservations.where((r) => r.status == ReservationStatus.approved).toList()),
            _buildReservationList(allReservations.where((r) => r.status == ReservationStatus.pending).toList()),
            _buildReservationList(allReservations.where((r) => r.status == ReservationStatus.rejected).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationList(List<ReservationModel> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Reservations Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        return ReservationCard(reservation: list[index]);
      },
    );
  }
}
