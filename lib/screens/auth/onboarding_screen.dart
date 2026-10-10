// Onboarding: 3 illustrated pages seen once (saved in SharedPreferences).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../utils/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _index = 0;

  static const List<(IconData, String, String)> _pages =
      <(IconData, String, String)>[
    (
      Icons.account_balance_wallet_outlined,
      'كل معاملاتك في مكان واحد',
      'سجّل دخلك ومصروفك في أقل من ٣ ثوانٍ، وتحكم في ميزانيتك بذكاء.'
    ),
    (
      Icons.auto_awesome,
      'محاسب شخصي بالذكاء الاصطناعي',
      'اسأل بالعربي: «كم صرفت على المطاعم الشهر ده؟» والإجابة تكون عندك فوراً.'
    ),
    (
      Icons.document_scanner_outlined,
      'صوّر الفاتورة وخلاص',
      'بضغطة زر واحدة يتم تحليل الفاتورة وتسجيلها تلقائياً في حسابك.'
    ),
  ];

  Future<void> _finish() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.onboardingSeen, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'تخطي',
                  style: TextStyle(color: AppColors.textHint),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (_, int i) {
                  final (IconData icon, String title, String body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[
                                AppColors.navy,
                                Color(0xFF164080)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(48),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.navy.withOpacity(0.25),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: AppColors.green, size: 84),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Tajawal',
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                _pages.length,
                (int i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _index ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _index ? AppColors.green : AppColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: ElevatedButton(
                onPressed: isLast
                    ? _finish
                    : () => _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        ),
                child: Text(isLast ? 'ابدأ الآن' : 'التالي'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
