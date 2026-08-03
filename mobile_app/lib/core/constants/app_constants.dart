class AppConstants {
  static const String appName = 'LifeLynk AI';
  static const String appVersion = '1.0.0';
  static const String apiBaseUrl = 'https://api.lifelynk.ai/api/v1'; // FastAPI Backend endpoint

  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const List<String> cities = [
    'Lahore',
    'Karachi',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Quetta',
  ];

  static const List<String> sampleAiQuestions = [
    'Which blood group is compatible with O-?',
    'Where can I donate blood near me?',
    'What should I do before donating blood?',
    'Which hospital has AB+ blood available right now?',
  ];
}
