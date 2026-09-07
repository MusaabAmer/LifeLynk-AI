import 'package:flutter/foundation.dart';

import '../../../../core/network/api_client.dart';
import '../models/search_result_model.dart';

class SearchRepository {
  Future<List<SearchResultModel>> searchOrganizations({
    String? bloodGroup,
    String? province,
    String? city,
  }) async {
    final queryParameters =
        <String, dynamic>{};

    if (bloodGroup != null &&
        bloodGroup.trim().isNotEmpty) {
      queryParameters['blood_group'] =
          bloodGroup.trim();
    }

    if (province != null &&
        province.trim().isNotEmpty) {
      queryParameters['province'] =
          province.trim();
    }

    if (city != null &&
        city.trim().isNotEmpty) {
      queryParameters['city'] =
          city.trim();
    }

    debugPrint(
      'Search API: /search/organizations',
    );

    debugPrint(
      'Search filters: $queryParameters',
    );

    final response =
        await ApiClient.get<dynamic>(
      '/search/organizations',
      queryParameters:
          queryParameters,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Search failed. '
        'Status code: ${response.statusCode}. '
        'Response: ${response.data}',
      );
    }

    final decoded = response.data;

    if (decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            SearchResultModel.fromJson,
          )
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];

      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(
              SearchResultModel.fromJson,
            )
            .toList();
      }

      final results = decoded['results'];

      if (results is List) {
        return results
            .whereType<Map<String, dynamic>>()
            .map(
              SearchResultModel.fromJson,
            )
            .toList();
      }
    }

    throw Exception(
      'Invalid search response format.',
    );
  }
}