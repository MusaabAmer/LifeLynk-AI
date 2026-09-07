import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/search_result_model.dart';
import '../data/repositories/search_repository.dart';

class SearchProvider extends ChangeNotifier {
  final SearchRepository repository;

  SearchProvider({
    required this.repository,
  });

  List<SearchResultModel> _results = [];

  List<SearchResultModel> get results =>
      List.unmodifiable(_results);

  bool _loading = false;

  bool get loading => _loading;

  String? _error;

  String? get error => _error;

  String? _selectedBloodGroup;

  String? get selectedBloodGroup =>
      _selectedBloodGroup;

  String? _selectedProvince;

  String? get selectedProvince =>
      _selectedProvince;

  String? _selectedCity;

  String? get selectedCity =>
      _selectedCity;

  Timer? _searchDebounce;

  int _searchRequestId = 0;

  void setBloodGroup(String? value) {
    _selectedBloodGroup = _clean(value);

    _scheduleSearch();

    notifyListeners();
  }

  void setProvince(String? value) {
    _selectedProvince = _clean(value);

    // City belongs to the selected province.
    _selectedCity = null;

    _scheduleSearch();

    notifyListeners();
  }

  void setCity(String? value) {
    _selectedCity = _clean(value);

    _scheduleSearch();

    notifyListeners();
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        search();
      },
    );
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  Future<void> search() async {
    final requestId =
        ++_searchRequestId;

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final results =
          await repository.searchOrganizations(
        bloodGroup:
            _selectedBloodGroup,
        province:
            _selectedProvince,
        city:
            _selectedCity,
      );

      // Ignore an old request that finished
      // after a newer request.
      if (requestId != _searchRequestId) {
        return;
      }

      _results = results;
    } catch (e, stackTrace) {
      if (requestId != _searchRequestId) {
        return;
      }

      debugPrint(
        'Search error: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      _results = [];

      _error =
          'Unable to search organizations.';
    } finally {
      if (requestId == _searchRequestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    await search();
  }

  void clearFilters() {
    _selectedBloodGroup = null;
    _selectedProvince = null;
    _selectedCity = null;

    _searchDebounce?.cancel();

    notifyListeners();

    search();
  }

  void clearResults() {
    ++_searchRequestId;

    _results = [];
    _error = null;
    _loading = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}