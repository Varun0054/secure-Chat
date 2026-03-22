import 'package:flutter/material.dart';
import 'package:secure_chat/views/login_view.dart';
import 'package:secure_chat/views/splash_view.dart';
import 'package:secure_chat/views/dashboard_view.dart';
import 'package:secure_chat/views/signup_view.dart';
import 'package:secure_chat/views/signin_view.dart';
import 'package:secure_chat/views/create_username_view.dart';

import 'package:secure_chat/views/search_user_view.dart';
import 'package:secure_chat/views/profile_view.dart';
import 'package:secure_chat/views/chat_view.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:secure_chat/firebase_options.dart';
import 'package:secure_chat/controller/theme_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'secrets.dart';

// ─── STEP 1: Top-level background message handler ────────────────────────────
// MUST be a top-level function (not inside any class).
// FCM calls this when the app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    // Ignore [core/duplicate-app] — Firebase may already be initialized natively.
    debugPrint('FCM BG handler Firebase init (ignored): $e');
  }
  debugPrint('FCM Background message: ${message.notification?.title}');
}

// ─── STEP 2: Local notifications plugin instance ─────────────────────────────
// Used to show heads-up banners when the app is in the FOREGROUND.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// High-importance Android notification channel (required for Android 8+)
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'high_importance_channel', // must match AndroidManifest.xml meta-data
  'High Importance Notifications',
  description: 'Used for chat push notifications',
  importance: Importance.high,
  playSound: true,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── STEP 2: Init Firebase safely (guard against native auto-init) ────────
  // On Android, google-services.json causes the native SDK to auto-init Firebase
  // before Dart runs. The [core/duplicate-app] error is thrown when we try to
  // init again. We swallow that specific error so startup never crashes.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // [core/duplicate-app] means Firebase was already initialized — that's fine.
    debugPrint('Firebase.initializeApp (ignored duplicate): $e');
  }

  // ─── STEP 3: Register the background handler ─────────────────────────────
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ─── STEP 4: Create the high-importance Android notification channel ──────
  // Without this, Android 8+ silently drops foreground notifications.
  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  } catch (e) {
    debugPrint('Notification channel creation error (ignored): $e');
  }

  // ─── STEP 5: Init local notifications plugin ─────────────────────────────
  try {
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('Notification tapped: ${details.payload}');
      },
    );
  } catch (e) {
    debugPrint('Local notifications init error (ignored): $e');
  }

  // ─── STEP 6: Show foreground FCM messages as visible banners ─────────────
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    if (notification != null && android != null) {
      try {
        await flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      } catch (e) {
        debugPrint('Show notification error (ignored): $e');
      }
    }
  });

  // ─── STEP 7: Init Supabase ────────────────────────────────────────────────
  try {
    await Supabase.initialize(
      url: AppSecrets.supabaseUrl,
      anonKey: AppSecrets.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init error: $e');
    // App can still run offline — continue.
  }

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
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Colors.black87,
              contentTextStyle: const TextStyle(color: Colors.white),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
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
            snackBarTheme: SnackBarThemeData(
              backgroundColor: Colors.white,
              contentTextStyle: const TextStyle(color: Colors.black87),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashView(),
            '/login': (context) => LoginView(),
            '/signin': (context) => const SignInView(),
            '/dashboard': (context) => const DashboardView(),
            '/signup': (context) => const SignupView(),
            '/create_username': (context) => const CreateUsernameView(),
            '/search': (context) => const SearchUserView(),
            '/profile': (context) => const ProfileView(),
            '/chat': (context) => const ChatView(),
          },
        );
      },
    );
  }
}
