import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/organization_detail_model.dart';

class OrganizationRepository {
  Future<OrganizationDetailModel?> fetchOrganizationDetails(
    String id,
  ) async {
    final organizationId = id.trim();

    if (organizationId.isEmpty) {
      return null;
    }

    try {
      final response = await ApiClient.get<dynamic>(
        '/organizations/$organizationId',
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 404) {
          return null;
        }

        throw Exception(
          'Failed to load organization. '
          'Status code: ${response.statusCode}',
        );
      }

      final decoded = response.data;

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Invalid organization response from server.',
        );
      }

      dynamic organizationData = decoded;

      if (decoded['data'] is Map<String, dynamic>) {
        organizationData = decoded['data'];
      }

      if (organizationData is! Map<String, dynamic>) {
        throw Exception(
          'Invalid organization data from server.',
        );
      }

      return OrganizationDetailModel.fromJson(
        organizationData,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }

      throw Exception(
        'Unable to fetch organization details: '
        '${e.response?.data ?? e.message}',
      );
    } catch (e) {
      throw Exception(
        'Unable to fetch organization details: $e',
      );
    }
  }
}