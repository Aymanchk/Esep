import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/group_provider.dart';
import 'providers/notification_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  runApp(const FairSplitterApp());
}

class FairSplitterApp extends StatelessWidget {
  const FairSplitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (ctx) => ChatProvider(ctx.read<AuthProvider>().api),
          update: (ctx, auth, prev) => prev ?? ChatProvider(auth.api),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DebtProvider>(
          create: (ctx) => DebtProvider(ctx.read<AuthProvider>().api),
          update: (ctx, auth, prev) => prev ?? DebtProvider(auth.api),
        ),
        ChangeNotifierProxyProvider<AuthProvider, GroupProvider>(
          create: (ctx) => GroupProvider(ctx.read<AuthProvider>().api),
          update: (ctx, auth, prev) => prev ?? GroupProvider(auth.api),
        ),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (ctx) => NotificationProvider(ctx.read<AuthProvider>().api),
          update: (ctx, auth, prev) => prev ?? NotificationProvider(auth.api),
        ),
      ],
      child: MaterialApp(
        title: 'Fair Splitter',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const StartupScreen(),
      ),
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthProvider>();
    final result = await auth.restoreSession();
    if (!mounted) return;

    Widget destination;
    if (result == AuthRestoreResult.authenticated) {
      destination = const HomeShell();
    } else if (result == AuthRestoreResult.invalidToken) {
      destination = const LoginScreen();
    } else {
      final onboardingSeen = await auth.hasSeenOnboarding();
      if (!mounted) return;
      destination = onboardingSeen
          ? const LoginScreen()
          : const OnboardingScreen();
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
