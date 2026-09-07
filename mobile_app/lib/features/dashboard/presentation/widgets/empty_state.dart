import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';


class EmptyState extends StatelessWidget {

  final String animation;
  final String message;


  const EmptyState({
    super.key,
    required this.animation,
    required this.message,
  });


  @override
  Widget build(BuildContext context) {

    return Center(

      child: Column(

        children: [

          Lottie.asset(
            animation,
            width: 140,
          ),


          const SizedBox(height: 10),


          Text(
            message,
            textAlign: TextAlign.center,
            style:
                Theme.of(context)
                    .textTheme
                    .bodyMedium,
          ),

        ],

      ),

    );

  }

}