import 'package:flutter/material.dart';
import '../auth/login_view.dart';

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  int step = 1;

  void _nextStep() {
    if (step >= 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
      );
    } else {
      setState(() {
        step++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // Angka besar
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EBDD),
                    shape: BoxShape.circle,
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
                  child: Center(
                    child: Text(
                      '$step',
                      style: const TextStyle(
                        fontSize: 100,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8A6F4D),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: step == index + 1 ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: step == index + 1
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
                  onPressed: () {
                    _nextStep();
                  },
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
                    step >= 3 ? 'Mulai' : 'Lanjut',
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
