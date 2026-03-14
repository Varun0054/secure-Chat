import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignupController with ChangeNotifier {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final usernameController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  String? _usernameError;
  String? get usernameError => _usernameError;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  bool validateUsername(String username) {
    if (username.isEmpty) {
      _usernameError = 'Username is required';
      notifyListeners();
      return false;
    }

    final validCharacters = RegExp(r'^[a-z0-9._]+$');
    if (!validCharacters.hasMatch(username)) {
      _usernameError = 'Only lowercase letters, numbers, . and _ allowed';
      notifyListeners();
      return false;
    }

    if (username.length < 3 || username.length > 30) {
      _usernameError = 'Username must be between 3 and 30 characters';
      notifyListeners();
      return false;
    }

    if (username.contains('..') ||
        username.contains('__') ||
        username.contains('._') ||
        username.contains('_.')) {
      _usernameError = 'Username cannot contain consecutive special characters';
      notifyListeners();
      return false;
    }

    if (username.startsWith('.') ||
        username.startsWith('_') ||
        username.endsWith('.') ||
        username.endsWith('_')) {
      _usernameError = 'Username cannot start or end with . or _';
      notifyListeners();
      return false;
    }

    _usernameError = null;
    notifyListeners();
    return true;
  }

  Future<bool> checkUsernameUniqueness(String username) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      if (data != null) {
        _usernameError = 'Username already taken';
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      // If table doesn't exist or other error, we might want to fail safe or log
      debugPrint('Error checking username: $e');
      return true; // Assume available if check fails? Or block? Safe to block if we want strict uniqueness.
    }
  }

  Future<void> signUp(
    BuildContext context,
    GlobalKey<FormState> formKey,
  ) async {
    _usernameError = null;
    if (!formKey.currentState!.validate()) return;

    final username = usernameController.text.trim();
    if (!validateUsername(username)) return;

    _isLoading = true;
    notifyListeners();

    try {
      final isUnique = await checkUsernameUniqueness(username);
      if (!isUnique) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': username},
      );

      final user = authResponse.user;
      if (user != null) {
        // Create profile - We use upsert to handle cases where a profile might already exist
        // (e.g. from a trigger or a previous partial signup attempt)
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': username,
          'email': email,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signup successful! Welcome to SecureChat.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/dashboard',
            (route) => false,
          );
        }
      }
    } on AuthException catch (error) {
      if (context.mounted) {
        String errorMessage = error.message;
        if (error.message.contains('error sending confirmation email') ||
            error.message.contains('rate limit')) {
          errorMessage =
              'Server configuration error: Please check Supabase Email Settings (SMTP/Rate Limits).';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: $error'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    super.dispose();
  }
}
