import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginController {
  Future<void> onGoogleLogin() async {
    final client = Supabase.instance.client;

    await client.auth.signInWithOAuth(
      OAuthProvider.google,
      // Change to your app's actual scheme if different
      redirectTo: 'securechat://login-callback/',
    );
  }

  void navigateToSignup(BuildContext context) {
    Navigator.pushNamed(context, '/signup');
  }
}
