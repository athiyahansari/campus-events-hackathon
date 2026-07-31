import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/shared/splash_screen.dart';
import 'services/firestore_service.dart';
import 'services/push_notification_service.dart';

import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CampusEventsApp());
}

class CampusEventsApp extends StatelessWidget {
  const CampusEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider(create: (_) => FirestoreService()),
        Provider(
          create: (context) => PushNotificationService(context.read<FirestoreService>(), rootScaffoldMessengerKey),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Campus Events',
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: rootScaffoldMessengerKey,
            themeMode: themeProvider.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
