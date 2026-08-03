import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/models/hospital_model.dart';
import '../../shared/widgets/custom_button.dart';

class HospitalDetailsScreen extends StatelessWidget {
  final HospitalModel hospital;

  const HospitalDetailsScreen({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                hospital.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              background: Image.network(
                hospital.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary,
                  child: const Icon(Icons.local_hospital, size: 80, color: Colors.white),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hospital.bloodBankName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(hospital.address)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColors.secondary, size: 18),
                            const SizedBox(width: 8),
                            Text(hospital.workingHours, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: AppColors.success, size: 18),
                            const SizedBox(width: 8),
                            Text(hospital.phone),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.emergency, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Text('Emergency: ${hospital.emergencyContact}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Real-Time Blood Inventory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: hospital.bloodInventory.length,
                  itemBuilder: (context, index) {
                    final key = hospital.bloodInventory.keys.elementAt(index);
                    final count = hospital.bloodInventory[key]!;
                    return Container(
                      decoration: BoxDecoration(
                        color: count > 0 ? AppColors.primary.withAlpha(15) : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: count > 0 ? AppColors.primary : Colors.grey.shade400,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            key,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: count > 0 ? AppColors.primary : Colors.grey,
                            ),
                          ),
                          Text(
                            '$count Units',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: count > 0 ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Call',
                        icon: Icons.call,
                        isOutlined: true,
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dialing ${hospital.phone}...')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Navigate',
                        icon: Icons.navigation,
                        backgroundColor: AppColors.secondary,
                        onPressed: () => context.go('/maps'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: 'Reserve Blood Now',
                    icon: Icons.add_task,
                    onPressed: () => context.push('/reserve', extra: hospital),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
