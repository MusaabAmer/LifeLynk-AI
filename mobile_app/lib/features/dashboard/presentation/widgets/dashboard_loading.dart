import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';


class DashboardLoading extends StatelessWidget {

  const DashboardLoading({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    return Center(

      child: Column(

        mainAxisAlignment:
            MainAxisAlignment.center,

        children: [

          Lottie.asset(
            'assets/animations/dashboard_loading.json',
            width: 180,
          ),


          const SizedBox(height: 20),


          Text(
            "Loading your dashboard...",
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