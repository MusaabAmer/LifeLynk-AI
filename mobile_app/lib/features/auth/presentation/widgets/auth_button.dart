import 'package:flutter/material.dart';



class AuthButton extends StatelessWidget {


final String text;
final VoidCallback onPressed;


const AuthButton({

super.key,

required this.text,

required this.onPressed,

});



@override
Widget build(BuildContext context){


return SizedBox(

width:double.infinity,


height:55,


child:ElevatedButton(


onPressed:onPressed,


child:Text(

text,

style:
const TextStyle(

fontSize:16,

fontWeight:
FontWeight.bold,

),

),

),


);


}



}