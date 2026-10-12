import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/bill_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/group_provider.dart';
import 'providers/notification_provider.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const EsepApp());
}

class EsepApp extends StatelessWidget {
  const EsepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
          update: (ctx, auth, prev) =>
              prev ?? NotificationProvider(auth.api),
        ),
      ],
      child: MaterialApp(
        title: 'Esep',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const OnboardingScreen(),
      ),
    );
  }
}
