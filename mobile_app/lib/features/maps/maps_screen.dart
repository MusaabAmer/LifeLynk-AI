import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../shared/models/hospital_model.dart';

class NearbyMapsScreen extends StatefulWidget {
  const NearbyMapsScreen({super.key});

  @override
  State<NearbyMapsScreen> createState() => _NearbyMapsScreenState();
}

class _NearbyMapsScreenState extends State<NearbyMapsScreen> {
  HospitalModel _selectedHospital = ApiService.mockHospitals.first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Hospital & Map Route'),
      ),
      body: Stack(
        children: [
          // Interactive Map Simulation View
          Container(
            width: double.infinity,
            height: double.infinity,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            child: Stack(
              children: [
                // Stylized map grid background lines
                CustomPaint(
                  size: Size.infinite,
                  painter: _MapGridPainter(isDark: isDark),
                ),

                // Current user location pin
                Positioned(
                  left: MediaQuery.of(context).size.width * 0.45,
                  top: MediaQuery.of(context).size.height * 0.35,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppColors.secondary.withAlpha(80), blurRadius: 12)
                          ],
                        ),
                        child: const Icon(Icons.my_location, color: Colors.white, size: 24),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('You (Current)', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                ),

                // Map hospital pins
                ...ApiService.mockHospitals.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final hosp = entry.value;
                  final isSelected = hosp.id == _selectedHospital.id;

                  // Coordinates mapping offset on simulated map
                  final double left = (MediaQuery.of(context).size.width * 0.15) + (idx * 75);
                  final double top = (MediaQuery.of(context).size.height * 0.15) + (idx % 2 == 0 ? 50 : 160);

                  return Positioned(
                    left: left,
                    top: top,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedHospital = hosp),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isSelected ? 1.25 : 1.0,
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 40,
                              color: isSelected ? AppColors.primary : AppColors.secondary,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: Text(
                                hosp.name.split(' ').first,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Top filter bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Showing Hospitals & Blood Banks within 10 km',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune),
                      onPressed: () => context.go('/search'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Hospital Detail card bottom sheet
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedHospital.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_selectedHospital.distanceKm} km • ~12 mins',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedHospital.address,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/hospital-details', extra: _selectedHospital),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('View Details', style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/reserve', extra: _selectedHospital),
                            icon: const Icon(Icons.add_task, size: 16),
                            label: const Text('Reserve', style: TextStyle(fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isDark;
  _MapGridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(15))
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
