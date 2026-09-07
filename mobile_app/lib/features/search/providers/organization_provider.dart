import 'package:flutter/material.dart';

import '../data/models/organization_detail_model.dart';
import '../data/repositories/organization_repository.dart';

class OrganizationProvider extends ChangeNotifier {
  final OrganizationRepository repository;

  OrganizationProvider({
    required this.repository,
  });

  OrganizationDetailModel? _organization;

  OrganizationDetailModel? get organization =>
      _organization;

  bool _loading = false;

  bool get loading => _loading;

  String? _error;

  String? get error => _error;

  Future<void> loadOrganization(String id) async {
    if (id.trim().isEmpty) {
      _error = 'Organization ID is required.';
      _organization = null;
      notifyListeners();
      return;
    }

    try {
      _loading = true;
      _error = null;

      notifyListeners();

      final organization =
          await repository.fetchOrganizationDetails(id);

      _organization = organization;
    } catch (e) {
      _error = e.toString();
      _organization = null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearOrganization() {
    _organization = null;
    _error = null;
    _loading = false;

    notifyListeners();
  }
}