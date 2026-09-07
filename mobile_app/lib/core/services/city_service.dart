import 'dart:convert';

import 'package:flutter/services.dart';


class CityService {


  static Map<String, dynamic>? _cache;



  static Future<Map<String, dynamic>> _load() async {


    if (_cache != null) {

      return _cache!;

    }



    final jsonString =
        await rootBundle.loadString(
      'assets/data/pakistan_locations.json',
    );



    _cache =
        json.decode(jsonString)
            as Map<String, dynamic>;



    return _cache!;


  }




  static Future<List<String>> getProvinces() async {


    final data =
        await _load();



    final states =
        data["states"] as List;



    final provinces =
        states
            .map<String>(
              (state) =>
                  state["name"].toString(),
            )
            .toList();



    provinces.sort();



    return provinces;


  }





  static Future<List<String>> getCities(

    String province,

  ) async {


    final data =
        await _load();



    final states =
        data["states"] as List;



    Map<String, dynamic>? selectedState;



    for (final state in states) {


      if (state["name"] == province) {


        selectedState =
            state as Map<String, dynamic>;


        break;


      }


    }




    if (selectedState == null) {


      return [];


    }




    final cities =
        selectedState["cities"] as List;



    final cityList =
        cities
            .map<String>(
              (city) =>
                  city["name"].toString(),
            )
            .toList();



    cityList.sort();



    return cityList;


  }



}