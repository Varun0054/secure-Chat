import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileController with ChangeNotifier {
  String? _username;
  String? get username => _username;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _friendRequests = [];
  List<Map<String, dynamic>> get friendRequests => _friendRequests;

  Future<void> fetchUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          _username = data['username'] as String?;
        }
        debugPrint(
          'fetchUserProfile: Username is $_username. Fetching requests...',
        );
        await fetchFriendRequests();
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFriendRequests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      debugPrint(
        'fetchFriendRequests: Requesting joined data for ${user.id}...',
      );

      final data = await Supabase.instance.client
          .from('friendships')
          .select('id, user_id1, profiles:user_id1(id, username, email)')
          .eq('user_id2', user.id)
          .eq('status', 'pending');

      debugPrint('fetchFriendRequests: Data received: $data');

      _friendRequests = List<Map<String, dynamic>>.from(data);
      notifyListeners();

      debugPrint(
        'fetchFriendRequests: Successfully updated state with ${_friendRequests.length} requests',
      );
    } catch (e) {
      debugPrint('Error fetching friend requests: $e');
    }
  }

  Future<bool> acceptFriendRequest(String friendshipId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', friendshipId);

      _friendRequests.removeWhere((element) => element['id'] == friendshipId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error accepting request: $e');
      return false;
    }
  }

  Future<bool> rejectFriendRequest(String friendshipId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .update({'status': 'rejected'})
          .eq('id', friendshipId);

      _friendRequests.removeWhere((element) => element['id'] == friendshipId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      return false;
    }
  }

  Future<void> logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
