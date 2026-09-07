import 'package:flutter/material.dart';

class ProvinceDropdown extends StatelessWidget {
  final String? value;
  final List<String> provinces;
  final ValueChanged<String> onChanged;

  const ProvinceDropdown({
    super.key,
    required this.value,
    required this.provinces,
    required this.onChanged,
  });

  Future<void> _showProvincePicker(
    BuildContext context,
  ) async {
    final searchController = TextEditingController();

    List<String> filtered =
        List<String>.from(provinces);

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
              title:
                  const Text("Select Province"),
              content: SizedBox(
                width: 400,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller:
                          searchController,
                      decoration:
                          InputDecoration(
                        hintText:
                            "Search province...",
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
                          filtered = provinces
                              .where(
                                (province) => province
                                    .toLowerCase()
                                    .contains(
                                      value
                                          .toLowerCase(),
                                    ),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder:
                            (context, index) {
                          final province =
                              filtered[index];

                          return ListTile(
                            title:
                                Text(province),
                            onTap: () {
                              Navigator.pop(
                                  context);

                              onChanged(
                                  province);
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
      onTap: () =>
          _showProvincePicker(context),
      borderRadius:
          BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "Province",
          prefixIcon:
              Icon(Icons.location_city),
          border: OutlineInputBorder(),
        ),
        child: Text(
          value ?? "Select Province",
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