import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import '../models/onboarding_model.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() =>
      _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController controller = PageController();

  int currentPage = 0;

  final List<OnboardingModel> pages = [
    OnboardingModel(
      image: "assets/images/onboarding/onboarding_1.png",
      title: "Urgent Blood Finder",
      description:
          "Locate nearby hospitals and blood banks with real-time blood availability in seconds.",
    ),

    OnboardingModel(
      image: "assets/images/onboarding/onboarding_2.png",
      title: "AI-Powered Assistant",
      description:
          "Ask LifeLynk AI about blood compatibility, donation eligibility, emergency guidance, and healthcare support.",
    ),

    OnboardingModel(
      image: "assets/images/onboarding/onboarding_3.png",
      title: "Instant Emergency SOS",
      description:
          "One-tap Emergency SOS instantly notifies nearby hospitals, blood banks, and eligible blood donors.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xffF7FBFF),
              Color(0xffEEF6FF),
              Colors.white,
            ],
          ),
        ),

        child: SafeArea(
          child: Column(
            children: [

              //--------------------------------------------------
              // Skip Button
              //--------------------------------------------------

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (currentPage != pages.length - 1)
                      TextButton(
                        onPressed: completeOnboarding,
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xff003366),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              //--------------------------------------------------
              // Pages
              //--------------------------------------------------

              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: pages.length,

                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },

                  itemBuilder: (context, index) {
                    final page = pages[index];

                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 25),

                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          Image.asset(
                            page.image,
                            height: 290,
                          ),

                          const SizedBox(height: 40),

                          Text(
                            page.title,
                            textAlign: TextAlign.center,

                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xff003366),
                                ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            page.description,

                            textAlign: TextAlign.center,

                            style: const TextStyle(
                              fontSize: 17,
                              color: Colors.black54,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              //--------------------------------------------------
              // Indicators
              //--------------------------------------------------

              Row(
                mainAxisAlignment: MainAxisAlignment.center,

                children: List.generate(
                  pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),

                    margin:
                        const EdgeInsets.symmetric(horizontal: 5),

                    height: 10,

                    width: currentPage == index ? 30 : 10,

                    decoration: BoxDecoration(
                      color: currentPage == index
                          ? const Color(0xffC62828)
                          : Colors.grey.shade300,

                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),

              //--------------------------------------------------
              // Next Button
              //--------------------------------------------------

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30),

                child: SizedBox(
                  width: 280,
                  height: 56,

                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xffC62828),

                      foregroundColor: Colors.white,

                      elevation: 8,

                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                    ),

                    onPressed: () {
                      if (currentPage ==
                          pages.length - 1) {
                        completeOnboarding();
                      } else {
                        controller.nextPage(
                          duration:
                              const Duration(milliseconds: 350),
                          curve: Curves.easeInOut,
                        );
                      }
                    },

                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          currentPage == pages.length - 1
                              ? "Get Started"
                              : "Next",

                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(width: 10),

                        const Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 35),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> completeOnboarding() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setBool(
      "onboarding_completed",
      true,
    );

    if (!mounted) return;

    context.go('/login');
  }
}