import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/chat_utils.dart';

class DashboardController with ChangeNotifier {
  String? _username;
  String? get username => _username;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> get friends => _friends;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;

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
        await fetchFriends();
        await fetchPendingRequests();
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchFriends() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final sent = await Supabase.instance.client
          .from('friendships')
          .select('user_id2, profiles:user_id2(id, username, email)')
          .eq('user_id1', user.id)
          .eq('status', 'accepted');

      final received = await Supabase.instance.client
          .from('friendships')
          .select('user_id1, profiles:user_id1(id, username, email)')
          .eq('user_id2', user.id)
          .eq('status', 'accepted');

      _friends = [];
      for (var item in sent) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        if (profile != null) _friends.add(profile);
      }
      for (var item in received) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        if (profile != null) _friends.add(profile);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching friends: $e');
    }
  }

  Future<void> fetchPendingRequests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Only fetch requests where I am the recipient
      final data = await Supabase.instance.client
          .from('friendships')
          .select('id, user_id1, profiles:user_id1(id, username, email)')
          .eq('user_id2', user.id)
          .eq('status', 'pending');

      _pendingRequests = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching pending requests: $e');
    }
  }

  Future<void> acceptRequest(String requestId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', requestId);

      await fetchFriends();
      await fetchPendingRequests();
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
  }

  Future<String?> getOrCreateRoom(String targetUserId) async {
    return ChatUtils.getOrCreateRoom(targetUserId);
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await Supabase.instance.client
          .from('friendships')
          .delete()
          .eq('id', requestId);

      await fetchPendingRequests();
    } catch (e) {
      debugPrint('Error rejecting request: $e');
    }
  }

  Future<void> logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
