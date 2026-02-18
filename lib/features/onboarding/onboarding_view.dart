import 'package:flutter/material.dart';
import '../auth/login_view.dart';
import 'onboarding_controller.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  late final OnboardingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingController();
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  void _handleNextStep() {
    if (_controller.isLastStep) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    } else {
      _controller.nextStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentData = _controller.currentData;

    return Scaffold(
      backgroundColor: const Color(0xFFE6D8C3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Teks Halaman Onboarding
                const Text(
                  'Halaman Onboarding',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3D3D3D),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 20),
                // Gambar Onboarding
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EBDD),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFC2A35C),
                      width: 3,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(currentData.image, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 20),
                // Deskripsi gambar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    currentData.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF5D5D5D),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_controller.totalSteps, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _controller.currentStep == index + 1 ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _controller.currentStep == index + 1
                            ? const Color(0xFFC2A35C)
                            : const Color(0xFF8B7D6B).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
                // Tombol Lanjut
                ElevatedButton(
                  onPressed: _handleNextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A6F4D),
                    foregroundColor: const Color(0xFFF3EBDD),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 14,
                    ),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _controller.buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
