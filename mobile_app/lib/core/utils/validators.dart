class Validators {
  Validators._();

  static String? requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "This field is required";
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return "Email is required";
    }

    final regex =
        RegExp(r'^[^@]+@[^@]+\.[^@]+');

    if (!regex.hasMatch(value)) {
      return "Enter a valid email";
    }

    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return "Phone number is required";
    }

    if (value.length < 11) {
      return "Invalid phone number";
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.length < 8) {
      return "Minimum 8 characters";
    }

    return null;
  }
}