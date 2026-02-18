import 'package:flutter/material.dart';

class OnboardingData {
  final String image;
  final String description;

  const OnboardingData({required this.image, required this.description});
}

class OnboardingController extends ChangeNotifier {
  int _currentStep = 1;
  final int totalSteps = 3;

  // Data untuk setiap halaman onboarding
  final List<OnboardingData> onboardingData = const [
    OnboardingData(
      image: 'assets/images/onboarding_view_1.jpeg',
      description:
          'Login akan selalu dibutuhkan oleh setiap user, untuk akun login ada di bawah form login',
    ),
    OnboardingData(
      image: 'assets/images/onboarding_view_2.jpeg',
      description:
          'Disini merupakan counting dari user yang bisa dikustom masing-masing oleh user',
    ),
    OnboardingData(
      image: 'assets/images/onboarding_view_3.jpeg',
      description: 'Keluar akun ketika penggunaan aplikasi sudah selesai',
    ),
  ];

  int get currentStep => _currentStep;

  OnboardingData get currentData => onboardingData[_currentStep - 1];

  bool get isLastStep => _currentStep >= totalSteps;

  String get buttonText => isLastStep ? 'Mulai' : 'Lanjut';

  void nextStep() {
    if (!isLastStep) {
      _currentStep++;
      notifyListeners();
    }
  }

  void goToStep(int step) {
    if (step >= 1 && step <= totalSteps) {
      _currentStep = step;
      notifyListeners();
    }
  }

  void reset() {
    _currentStep = 1;
    notifyListeners();
  }
}
