import 'package:flutter/material.dart';

class LoginController {
  void onGoogleLogin() {
    // TODO: Implement Google Login logic
    debugPrint("Google Login Pressed");
  }

  void navigateToSignup(BuildContext context) {
    Navigator.pushNamed(context, '/signup');
  }
}
