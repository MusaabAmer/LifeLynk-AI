import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../shared/models/hospital_model.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/reservation_provider.dart';
import '../../shared/widgets/custom_button.dart';
import '../../shared/widgets/custom_text_field.dart';

class BloodReservationScreen extends ConsumerStatefulWidget {
  final HospitalModel hospital;

  const BloodReservationScreen({super.key, required this.hospital});

  @override
  ConsumerState<BloodReservationScreen> createState() => _BloodReservationScreenState();
}

class _BloodReservationScreenState extends ConsumerState<BloodReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _patientNameController;
  String _selectedBloodGroup = 'O+';
  int _unitsRequired = 1;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _patientNameController = TextEditingController(text: user?.fullName ?? '');
    _selectedBloodGroup = user?.bloodGroup ?? 'O+';
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final reservation = await ref.read(reservationProvider.notifier).createReservation(
          patientName: _patientNameController.text.trim(),
          hospitalName: widget.hospital.name,
          hospitalAddress: widget.hospital.address,
          bloodGroup: _selectedBloodGroup,
          units: _unitsRequired,
          date: _selectedDate,
        );

    if (reservation != null && mounted) {
      context.push('/reservation-confirmation', extra: reservation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservationState = ref.watch(reservationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blood Reservation Form')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: AppColors.primary.withAlpha(15),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, color: AppColors.primary, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.hospital.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              widget.hospital.address,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              CustomTextField(
                controller: _patientNameController,
                labelText: 'Patient Full Name',
                prefixIcon: Icons.person_outline,
                validator: (v) => Validators.validateRequired(v, 'Patient Name'),
              ),

              const SizedBox(height: 18),

              const Text('Blood Group Required', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedBloodGroup,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.bloodtype)),
                items: AppConstants.bloodGroups
                    .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBloodGroup = val);
                },
              ),

              const SizedBox(height: 18),

              const Text('Units Required', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _unitsRequired > 1 ? () => setState(() => _unitsRequired--) : null,
                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
                  ),
                  Text(
                    '$_unitsRequired Bag(s)',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: _unitsRequired < 5 ? () => setState(() => _unitsRequired++) : null,
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              const Text('Required Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(Formatters.formatDate(_selectedDate), style: const TextStyle(fontSize: 16)),
                      const Icon(Icons.calendar_today, size: 20, color: AppColors.primary),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Submit Reservation',
                  isLoading: reservationState.isLoading,
                  onPressed: _handleSubmit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
