import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeCtrl;
  late AnimationController _scaleCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  static const _neonColors = [
    Color(0xFF00E676),
    Color(0xFF00E5FF),
    Color(0xFFFFD740),
    Color(0xFF7C4DFF),
  ];

  final _pages = const [
    _OnboardPage(
      emoji: '\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}',
      title: 'Bienvenue dans\nSKS Family !',
      desc: 'Le systeme de points et recompenses\npour toute la famille par SKS',
      colorIndex: 0,
    ),
    _OnboardPage(
      emoji: '\u{2B50}',
      title: 'Points & Niveaux',
      desc: 'Attribuez des points pour les bons\ncomportements et suivez la progression',
      colorIndex: 1,
    ),
    _OnboardPage(
      emoji: '\u{1F3C6}',
      title: 'Badges & Objectifs',
      desc: 'Debloquez des badges, fixez des objectifs\net motivez vos enfants !',
      colorIndex: 2,
    ),
    _OnboardPage(
      emoji: '\u{1F512}',
      title: 'Code Parental',
      desc: 'Protegez les reglages avec un code PIN\npour que seuls les parents modifient les scores',
      colorIndex: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fadeCtrl.forward();
    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _neonColors[_currentPage % _neonColors.length];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Passer', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) {
                    setState(() => _currentPage = i);
                    _scaleCtrl.reset();
                    _scaleCtrl.forward();
                  },
                  itemCount: _pages.length,
                  itemBuilder: (_, i) {
                    final page = _pages[i];
                    final pageColor = _neonColors[page.colorIndex];
                    return FadeTransition(
                      opacity: _fadeAnim,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _scaleAnim,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  color: pageColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: pageColor.withValues(alpha: 0.3), width: 2),
                                  boxShadow: [
                                    BoxShadow(color: pageColor.withValues(alpha: 0.2), blurRadius: 24),
                                  ],
                                ),
                                child: Center(child: Text(page.emoji, style: const TextStyle(fontSize: 72))),
                              ),
                            ),
                            const SizedBox(height: 40),
                            NeonText(
                              text: page.title,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: pageColor,
                              glowIntensity: 0.4,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.desc,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey[400], height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final dotColor = _neonColors[i % _neonColors.length];
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == i ? 28 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _currentPage == i ? dotColor : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: _currentPage == i
                            ? [BoxShadow(color: dotColor.withValues(alpha: 0.4), blurRadius: 8)]
                            : null,
                      ),
                    );
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16)],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: _nextPage,
                        child: Center(
                          child: Text(
                            _currentPage == _pages.length - 1 ? 'Commencer !' : 'Suivant',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPage {
  final String emoji;
  final String title;
  final String desc;
  final int colorIndex;
  const _OnboardPage({required this.emoji, required this.title, required this.desc, required this.colorIndex});
}
