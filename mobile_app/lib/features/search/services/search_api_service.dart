import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/organization_detail_model.dart';


class SearchApiService {


  final String baseUrl;


  SearchApiService({

    required this.baseUrl,

  });



  Future<OrganizationDetailModel>
      getOrganizationDetails(

      String organizationId,

  ) async {



    final response = await http.get(

      Uri.parse(

        "$baseUrl/organizations/$organizationId",

      ),

    );



    if(response.statusCode == 200){


      final data =
          jsonDecode(response.body);



      return OrganizationDetailModel
          .fromJson(data);



    } else {


      throw Exception(

        "Failed to load organization details",

      );

    }

  }


}