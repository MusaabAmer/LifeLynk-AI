import 'package:flutter/material.dart';

class CityDropdown extends StatelessWidget {
  final String? value;
  final List<String> cities;
  final ValueChanged<String> onChanged;

  const CityDropdown({
    super.key,
    required this.value,
    required this.cities,
    required this.onChanged,
  });

  Future<void> _showCityPicker(BuildContext context) async {
    final TextEditingController searchController =
        TextEditingController();

    List<String> filteredCities =
        List<String>.from(cities);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(20),
              ),
              title: const Text(
                "Select City",
              ),
              content: SizedBox(
                width: 400,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search city...",
                        prefixIcon:
                            const Icon(Icons.search),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          filteredCities = cities
                              .where(
                                (city) => city
                                    .toLowerCase()
                                    .contains(
                                      value.toLowerCase(),
                                    ),
                              )
                              .toList();
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: filteredCities.isEmpty
                          ? const Center(
                              child: Text(
                                "No city found",
                              ),
                            )
                          : ListView.builder(
                              itemCount:
                                  filteredCities.length,
                              itemBuilder:
                                  (context, index) {
                                final city =
                                    filteredCities[
                                        index];

                                return ListTile(
                                  title: Text(city),
                                  onTap: () {
                                    Navigator.pop(
                                        context);

                                    onChanged(city);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(12),
      onTap: () => _showCityPicker(context),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "City",
          prefixIcon:
              Icon(Icons.location_on),
          border: OutlineInputBorder(),
        ),
        child: Text(
          value ?? "Select City",
          style: TextStyle(
            color: value == null
                ? Colors.grey
                : Colors.black,
          ),
        ),
      ),
    );
  }
}