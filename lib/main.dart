import 'package:flutter/material.dart';
import 'package:secure_chat/views/login_view.dart';
import 'package:secure_chat/views/splash_view.dart';
import 'package:secure_chat/views/dashboard_view.dart';
import 'package:secure_chat/views/signup_view.dart';
import 'package:secure_chat/views/signin_view.dart';

import 'package:secure_chat/views/search_user_view.dart';
import 'package:secure_chat/views/profile_view.dart';
import 'package:secure_chat/views/chat_view.dart';

import 'package:secure_chat/controller/theme_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://qcrruzhpumgyqewhcwup.supabase.co',
    anonKey: 'sb_publishable_94pQ5A1ErMtzYqKXeKA-7w_FrgTw5sY',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeController();

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: themeController.themeMode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.grey[100],
            primaryColor: Colors.blueAccent,
            colorScheme: ColorScheme.light(
              primary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.black),
              bodyMedium: TextStyle(color: Colors.black87),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F1223),
            primaryColor: Colors.blueAccent,
            colorScheme: ColorScheme.dark(
              primary: Colors.white,
              surface: Colors.white.withValues(alpha: 0.05),
              onSurface: Colors.white,
            ),
            textTheme: const TextTheme(
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
            iconTheme: const IconThemeData(color: Colors.white70),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashView(),
            '/login': (context) => LoginView(),
            '/signin': (context) => const SignInView(),
            '/dashboard': (context) => const DashboardView(),
            '/signup': (context) => const SignupView(),
            '/search': (context) => const SearchUserView(),
            '/profile': (context) => const ProfileView(),
            '/chat': (context) => const ChatView(),
          },
        );
      },
    );
  }
}
