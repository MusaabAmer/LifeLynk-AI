import 'dart:io';

import 'package:image_picker/image_picker.dart';

class ImagePickerService {

  static final ImagePicker
      _picker = ImagePicker();

  static Future<File?> pickImage() async {

    final image =
        await _picker.pickImage(

      source: ImageSource.gallery,

      imageQuality: 80,

    );

    if (image == null) {
      return null;
    }

    return File(
      image.path,
    );

  }

}