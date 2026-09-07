import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditableProfileAvatar extends StatefulWidget {
  final File? initialImage;
  final ValueChanged<File?>? onImageSelected;

  const EditableProfileAvatar({
    super.key,
    this.initialImage,
    this.onImageSelected,
  });

  @override
  State<EditableProfileAvatar> createState() =>
      _EditableProfileAvatarState();
}

class _EditableProfileAvatarState
    extends State<EditableProfileAvatar> {

  final ImagePicker _picker = ImagePicker();

  File? _image;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null) return;

    final file = File(picked.path);

    setState(() {
      _image = file;
    });

    widget.onImageSelected?.call(file);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        children: [

          CircleAvatar(
            radius: 55,
            backgroundImage:
                _image != null
                    ? FileImage(_image!)
                    : null,
            child: _image == null
                ? const Icon(
                    Icons.person,
                    size: 55,
                  )
                : null,
          ),

          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _pickImage,
              child: const CircleAvatar(
                radius: 18,
                child: Icon(Icons.camera_alt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}