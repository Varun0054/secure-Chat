import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Simulate a delay for the splash screen
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final bool isLoggedIn = session != null;

      if (isLoggedIn) {
        try {
          // Timeout added to prevent infinite hanging when internet is poor or disconnected
          final profile = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', session.user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 7));

          if (!mounted) return;

          if (profile != null && profile['username'] != null && profile['username'].toString().isNotEmpty) {
            try {
              await LocalDatabaseService.saveCacheString('current_username', profile['username'].toString());
            } catch (e) {
              debugPrint('LocalDB error while saving username: $e');
            }
            Navigator.pushReplacementNamed(context, '/dashboard');
          } else {
            Navigator.pushReplacementNamed(context, '/create_username');
          }
        } catch (e) {
          debugPrint('Network/Supabase error in splash: $e');
          // Fallback to local cache if offline/failed
          try {
            final cachedUsername = await LocalDatabaseService.getCacheString('current_username');
            if (!mounted) return;
            if (cachedUsername != null && cachedUsername.isNotEmpty) {
              Navigator.pushReplacementNamed(context, '/dashboard');
            } else {
              Navigator.pushReplacementNamed(context, '/create_username');
            }
          } catch (cacheError) {
            debugPrint('LocalDB cache error in splash fallback: $cacheError');
            if (!mounted) return;
            // Unhandled exception here means no local db (e.g. Chrome/Web or unsupported desktop without ffi)
            Navigator.pushReplacementNamed(context, '/dashboard'); // Assume logged in if auth is valid, dash will handle rest.
          }
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      debugPrint('Unexpected error in splash check: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Colors.greenAccent),
            const SizedBox(height: 20),
            const Text(
              'SecureChat',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "End-to-End Encrypted Messaging",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
