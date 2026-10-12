import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'register_screen.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum LoginStep { phone, otp, email }

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  LoginStep _step = LoginStep.phone;
  bool _obscurePassword = true;
  late AnimationController _floatController;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.sendOtp(_phoneController.text.trim());
    if (ok && mounted) {
      setState(() {
        _step = LoginStep.otp;
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(
      _phoneController.text.trim(),
      _otpController.text.trim(),
    );
    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }

  void _continueAsGuest() {
    context.read<AuthProvider>().continueAsGuest();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Cool ambient blobs
            Positioned(
              top: -60,
              right: -40,
              child: _Blob(color: const Color(0xFF22D3EE), size: 200),
            ),
            Positioned(
              bottom: -40,
              left: -60,
              child: _Blob(color: const Color(0xFF67E8F9), size: 180),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.4,
              right: -30,
              child: _Blob(color: const Color(0xFFA78BFA), size: 120),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 32),

                        // Floating mascot
                        AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (_, __) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: const Icon(Icons.account_balance_wallet_rounded,
                                size: 56, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppTheme.primaryGradient.createShader(bounds),
                          child: Text(
                            'Esep',
                            style: AppTheme.headingStyle(fontSize: 34).copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _step == LoginStep.otp ? 'Подтверждение кода' : 'Войдите в аккаунт',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Glass form card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border(
                                  top: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.18)),
                                  left: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.12)),
                                  right: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.06)),
                                  bottom: BorderSide(
                                      color: Colors.white
                                          .withValues(alpha: 0.06)),
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (_step == LoginStep.phone) ...[
                                    TextFormField(
                                      key: const ValueKey('phone_field'),
                                      controller: _phoneController,
                                      decoration: const InputDecoration(
                                        labelText: 'Номер телефона',
                                        hintText: '+996 700 123 456',
                                        prefixIcon: Icon(Icons.phone_rounded),
                                      ),
                                      keyboardType: TextInputType.phone,
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Введите номер телефона';
                                        }
                                        return null;
                                      },
                                    ),
                                  ] else if (_step == LoginStep.otp) ...[
                                    Text(
                                      'Код отправлен на ${_phoneController.text}',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      key: const ValueKey('otp_field'),
                                      controller: _otpController,
                                      decoration: const InputDecoration(
                                        labelText: 'Код подтверждения',
                                        hintText: 'Введите 6 цифр',
                                        prefixIcon: Icon(Icons.lock_person_rounded),
                                        counterText: '',
                                      ),
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 20,
                                        letterSpacing: 6,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      validator: (v) {
                                        if (v == null || v.length != 6) {
                                          return 'Введите 6-значный код';
                                        }
                                        return null;
                                      },
                                    ),
                                  ] else ...[
                                    TextFormField(
                                      controller: _emailController,
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'email@example.com',
                                        prefixIcon: Icon(Icons.email_outlined),
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) {
                                          return 'Введите email';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passwordController,
                                      decoration: InputDecoration(
                                        labelText: 'Пароль',
                                        hintText: 'Введите пароль',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(_obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined),
                                          onPressed: () => setState(() =>
                                              _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                      obscureText: _obscurePassword,
                                      style: const TextStyle(color: AppTheme.textPrimary),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Введите пароль';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                  if (auth.error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        auth.error!,
                                        style: const TextStyle(
                                          color: AppTheme.danger,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Login button
                        GestureDetector(
                          onTap: auth.isLoading
                              ? null
                              : () {
                                  if (_step == LoginStep.phone) {
                                    _sendOtp();
                                  } else if (_step == LoginStep.otp) {
                                    _verifyOtp();
                                  } else {
                                    _login();
                                  }
                                },
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.45),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _step == LoginStep.phone
                                              ? 'Получить код'
                                              : _step == LoginStep.otp
                                                  ? 'Подтвердить'
                                                  : 'Войти',
                                          style: const TextStyle(
                                            color: Color(0xFF1A1A1A),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded,
                                            color: Color(0xFF1A1A1A), size: 18),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Alternate login actions
                        if (_step == LoginStep.otp)
                          GestureDetector(
                            onTap: () => setState(() => _step = LoginStep.phone),
                            child: const Text(
                              'Изменить номер телефона',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (_step == LoginStep.phone)
                          GestureDetector(
                            onTap: () => setState(() => _step = LoginStep.email),
                            child: const Text(
                              'Войти по Email',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () => setState(() => _step = LoginStep.phone),
                            child: const Text(
                              'Войти по номеру телефона',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Нет аккаунта? ',
                              style:
                                  TextStyle(color: AppTheme.textSecondary),
                            ),
                            GestureDetector(
                              onTap: () {
                                auth.clearError();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Зарегистрироваться',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        GestureDetector(
                          onTap: _continueAsGuest,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.1)),
                                ),
                                child: const Text(
                                  'Продолжить без регистрации',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
        color: color.withValues(alpha: 0.18),
      ),
    );
  }
}
