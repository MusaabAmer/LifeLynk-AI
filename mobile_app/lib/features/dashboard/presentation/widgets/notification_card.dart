import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class NotificationCard extends StatelessWidget {

  final String title;
  final String message;
  final String time;
  final VoidCallback? onTap;


  const NotificationCard({
    super.key,
    required this.title,
    required this.message,
    required this.time,
    this.onTap,
  });


  @override
  Widget build(BuildContext context) {

    return Card(

      elevation: 2,

      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),


      child: InkWell(

        borderRadius:
            BorderRadius.circular(20),

        onTap: onTap,


        child: Padding(

          padding:
              const EdgeInsets.all(16),


          child: Row(

            children: [


              CircleAvatar(

                radius: 24,

                backgroundColor:
                    AppColors.info.withAlpha((0.12 * 255).round()),

                child: const Icon(
                  Icons.notifications,
                  color: AppColors.info,
                ),

              ),



              const SizedBox(width: 15),



              Expanded(

                child: Column(

                  crossAxisAlignment:
                      CrossAxisAlignment.start,


                  children: [


                    Text(

                      title,

                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),

                    ),



                    const SizedBox(height: 5),



                    Text(
                      message,
                    ),



                    const SizedBox(height: 5),



                    Text(

                      time,

                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,

                    ),


                  ],

                ),

              ),


            ],

          ),

        ),

      ),

    );

  }

}