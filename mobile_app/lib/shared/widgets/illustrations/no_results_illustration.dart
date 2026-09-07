import 'package:flutter/material.dart';

class NoResultsIllustration extends StatelessWidget {

const NoResultsIllustration({super.key});


@override
Widget build(BuildContext context){

return Column(

children:[

Icon(
Icons.search_off,
size:100,
color:Color(0xff003366),
),

SizedBox(height:20),

Icon(
Icons.bloodtype,
size:50,
color:Color(0xffC62828),
)

],

);

}

}