import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';

class CreateUsernameController with ChangeNotifier {
  final usernameController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _usernameError;
  String? get usernameError => _usernameError;

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
      debugPrint('Error checking username: $e');
      return true; 
    }
  }

  Future<void> saveUsername(BuildContext context, GlobalKey<FormState> formKey) async {
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

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception("User not authenticated.");
      }

      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id,
        'username': username,
        'email': user.email ?? '',
      });

      // Instantly cache the verified username locally
      try {
        await LocalDatabaseService.saveCacheString('current_username', username);
      } catch (cacheErr) {
        debugPrint('Cache error: $cacheErr');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username created! Welcome to SecureChat.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
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

  Future<void> cancel(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }
}
