import 'package:flutter/material.dart';

import '../../data/models/search_result_model.dart';


class AddressCard extends StatelessWidget {


  final SearchResultModel organization;


  const AddressCard({

    super.key,

    required this.organization,

  });



  @override
  Widget build(BuildContext context) {


    return Card(


      child: Padding(

        padding:
            const EdgeInsets.all(16),


        child: Column(


          crossAxisAlignment:
              CrossAxisAlignment.start,


          children: [



            Text(

              "Location",

              style:

                  Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(

                fontWeight:
                    FontWeight.bold,

              ),

            ),



            const SizedBox(
              height: 14,
            ),



            _AddressRow(

              icon:
                  Icons.location_on,

              text:
                  organization.address,

            ),




            const SizedBox(
              height: 10,
            ),



            _AddressRow(

              icon:
                  Icons.location_city,

              text:

                  "${organization.city}, ${organization.province}",

            ),



            const SizedBox(
              height: 16,
            ),




            SizedBox(

              width:
                  double.infinity,


              child:
                  OutlinedButton.icon(


                onPressed:

                    organization.latitude != null &&

                    organization.longitude != null

                        ?

                        () {

                         

                        }

                        :

                        null,



                icon:
                    const Icon(

                  Icons.map,

                ),



                label:
                    const Text(

                  "Open in OpenStreetMap",

                ),


              ),

            ),



          ],


        ),


      ),


    );


  }


}




class _AddressRow extends StatelessWidget {


  final IconData icon;


  final String text;



  const _AddressRow({

    required this.icon,

    required this.text,

  });



  @override
  Widget build(BuildContext context) {


    return Row(


      crossAxisAlignment:
          CrossAxisAlignment.start,


      children: [



        Icon(

          icon,

          size:
              20,

        ),




        const SizedBox(
          width: 10,
        ),




        Expanded(

          child:

              Text(

            text,

          ),

        ),



      ],


    );


  }


}