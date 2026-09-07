import 'package:flutter/material.dart';

class NoHospitalIllustration extends StatelessWidget {
  const NoHospitalIllustration({super.key});

  @override
  Widget build(BuildContext context) {

    return Column(
      children: [

        Icon(
          Icons.location_searching,
          size: 90,
          color: Color(0xff1E88E5),
        ),

        SizedBox(height:20),

        Icon(
          Icons.local_hospital,
          size:80,
          color: Color(0xffC62828),
        ),

        SizedBox(height:10),

        Icon(
          Icons.bloodtype,
          size:40,
          color: Color(0xffC62828),
        ),
      ],
    );
  }
}