import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hospital_model.dart';
import '../../services/api_service.dart';

class SearchState {
  final String selectedBloodGroup;
  final String selectedCity;
  final String hospitalFilter;
  final List<HospitalModel> results;
  final bool isLoading;

  const SearchState({
    this.selectedBloodGroup = 'O+',
    this.selectedCity = 'Lahore',
    this.hospitalFilter = '',
    this.results = const [],
    this.isLoading = false,
  });

  SearchState copyWith({
    String? selectedBloodGroup,
    String? selectedCity,
    String? hospitalFilter,
    List<HospitalModel>? results,
    bool? isLoading,
  }) {
    return SearchState(
      selectedBloodGroup: selectedBloodGroup ?? this.selectedBloodGroup,
      selectedCity: selectedCity ?? this.selectedCity,
      hospitalFilter: hospitalFilter ?? this.hospitalFilter,
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    performSearch();
    return const SearchState();
  }

  void setBloodGroup(String bg) {
    state = state.copyWith(selectedBloodGroup: bg);
  }

  void setCity(String city) {
    state = state.copyWith(selectedCity: city);
  }

  void setHospitalFilter(String text) {
    state = state.copyWith(hospitalFilter: text);
  }

  Future<void> performSearch() async {
    state = state.copyWith(isLoading: true);
    final results = await ApiService.searchBlood(
      bloodGroup: state.selectedBloodGroup,
      city: state.selectedCity,
      hospitalName: state.hospitalFilter,
    );
    state = state.copyWith(isLoading: false, results: results);
  }

  void clearFilters() {
    state = const SearchState(
      selectedBloodGroup: 'O+',
      selectedCity: 'Lahore',
      hospitalFilter: '',
      results: [],
      isLoading: false,
    );
    performSearch();
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
