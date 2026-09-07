import '../data/mock/mock_search_data.dart';
import '../data/models/search_result_model.dart';

class SearchService {
  Future<List<SearchResultModel>> searchOrganizations({
    String? bloodGroup,
    String? province,
    String? city,
  }) async {
    // Temporary delay.
    // This will later be replaced with the real API call.
    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    List<SearchResultModel> results = List<SearchResultModel>.from(
      mockSearchResults,
    );

    // Blood Group Filter
    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      results = results.where((item) {
        return item.bloodGroup.toLowerCase() ==
            bloodGroup.toLowerCase();
      }).toList();
    }

    // Province Filter
    if (province != null && province.isNotEmpty) {
      results = results.where((item) {
        return item.province.toLowerCase() ==
            province.toLowerCase();
      }).toList();
    }

    // City Filter
    if (city != null && city.isNotEmpty) {
      results = results.where((item) {
        return item.city.toLowerCase() ==
            city.toLowerCase();
      }).toList();
    }

    return results;
  }
}