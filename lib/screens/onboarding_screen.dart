import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_glass.dart';
import '../utils/tma_helper.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnim;
  late Animation<double> _floatAnim;
  final _pageController = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Дели всё честно',
      subtitle: 'Ресторан, продукты, поездка, аренда — разделяйте любые расходы без споров',
    ),
    _SlideData(
      icon: Icons.camera_alt_rounded,
      title: 'Сканируй чек — мы разберёмся',
      subtitle: 'Сфотографируйте любой чек, и мы распознаем все позиции',
    ),
    _SlideData(
      icon: Icons.payments_rounded,
      title: 'Каждый платит за своё',
      subtitle: 'Отслеживайте долги и отправляйте результат друзьям',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _floatAnim = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTelegramWebApp();
    });
  }

  void _checkTelegramWebApp() async {
    try {
      final initData = TmaHelper.getInitData();
      if (initData != null && initData.isNotEmpty) {
        final auth = context.read<AuthProvider>();
        final success = await auth.tryTelegramAutoLogin(initData);
        if (success && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeShell()),
          );
        }
      }
    } catch (e) {
      debugPrint('Telegram WebApp check failed: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _continueAsGuest() {
    context.read<AuthProvider>().continueAsGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _goToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Cool ambient blobs
            Positioned(
              top: -80,
              left: -60,
              child: _Blob(color: const Color(0xFF22D3EE), size: 280),
            ),
            Positioned(
              top: 100,
              right: -80,
              child: _Blob(color: const Color(0xFF67E8F9), size: 220),
            ),
            Positioned(
              bottom: 60,
              left: 40,
              child: _Blob(color: const Color(0xFFA78BFA), size: 180),
            ),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    const Spacer(flex: 1),

                    // Page view for slides
                    SizedBox(
                      height: 360,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: _slides.length,
                        itemBuilder: (_, i) {
                          final slide = _slides[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Floating emoji mascot
                                AnimatedBuilder(
                                  animation: _floatAnim,
                                  builder: (_, __) => Transform.translate(
                                    offset: Offset(0, -_floatAnim.value),
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppTheme.primary.withValues(alpha: 0.3),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(slide.icon,
                                            size: 72, color: AppTheme.primary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  slide.title,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.headingStyle(fontSize: 28),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  slide.subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: isActive
                                ? AppTheme.primary
                                : AppTheme.textSecondary.withValues(alpha: 0.3),
                          ),
                        );
                      }),
                    ),

                    const Spacer(flex: 1),

                    // Feature pills
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FeaturePill(Icons.camera_alt_rounded, 'Скан чека'),
                          const SizedBox(width: 8),
                          _FeaturePill(Icons.account_balance_wallet_rounded, 'Долги'),
                          const SizedBox(width: 8),
                          _FeaturePill(Icons.qr_code_rounded, 'QR Оплата'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // CTA buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Primary — Start
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.40),
                                    blurRadius: 20,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: FilledButton(
                                onPressed: _goToLogin,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Начать',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Ghost — Guest mode
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: LiquidGlass(
                              borderRadius: BorderRadius.circular(16),
                              interactive: true,
                              onTap: _continueAsGuest,
                              padding: EdgeInsets.zero,
                              child: Center(
                                child: Text(
                                  'Без регистрации',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Login link
                          GestureDetector(
                            onTap: _goToLogin,
                            child: RichText(
                              text: TextSpan(
                                text: 'Уже есть аккаунт? ',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Войти',
                                    style: TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SlideData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: BorderRadius.circular(50),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.20),
      ),
    );
  }
}
