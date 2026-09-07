import 'package:flutter/material.dart';

class CompleteProfileIllustration extends StatelessWidget {
  const CompleteProfileIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [

          CircleAvatar(
            radius: 70,
            backgroundColor: Colors.blue.shade50,
          ),

          const Icon(
            Icons.person,
            size: 90,
            color: Color(0xff003366),
          ),

          Positioned(
            right: 40,
            top: 40,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffC62828),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.bloodtype,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          Positioned(
            left: 40,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff1E88E5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}