import 'package:flutter/material.dart';


class ProfileAvatar extends StatelessWidget {

  final String imageUrl;
  final double radius;


  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
  });


  @override
  Widget build(BuildContext context) {

    return CircleAvatar(

      radius: radius,

      backgroundColor:
          Colors.grey.shade200,


      backgroundImage:
          imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,


      child:
          imageUrl.isEmpty
              ? Icon(
                  Icons.person,
                  size: radius,
                  color: Colors.grey,
                )
              : null,

    );

  }

}