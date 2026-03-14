import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SearchUserController with ChangeNotifier {
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> get searchResults => _searchResults;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Map to store friendship status: 'none', 'pending', 'accepted', 'received'
  // Key is user_id
  final Map<String, String> _friendStatus = {};
  Map<String, String> get friendStatus => _friendStatus;

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _friendStatus.clear();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, username, email')
          .ilike('username', '%$query%')
          .neq('id', currentUserId) // Exclude current user
          .limit(20);

      _searchResults = List<Map<String, dynamic>>.from(response);
      _friendStatus.clear();

      // Check friendship status for each found user
      if (_searchResults.isNotEmpty) {
        final targetIds = _searchResults.map((u) => u['id']).toList();

        // 1. Check requests I SENT (I am user_id1)
        final sentRequests = await Supabase.instance.client
            .from('friendships')
            .select('user_id2, status')
            .eq('user_id1', currentUserId)
            .inFilter('user_id2', targetIds);

        for (final req in sentRequests) {
          final targetId = req['user_id2'] as String;
          final status = req['status'] as String;
          if (status == 'accepted') {
            _friendStatus[targetId] = 'accepted';
          } else if (status == 'pending') {
            _friendStatus[targetId] = 'pending'; // Meaning "Request Sent"
          }
        }

        // 2. Check requests I RECEIVED (I am user_id2)
        final receivedRequests = await Supabase.instance.client
            .from('friendships')
            .select('user_id1, status')
            .eq('user_id2', currentUserId)
            .inFilter('user_id1', targetIds);

        for (final req in receivedRequests) {
          final senderId = req['user_id1'] as String;
          final status = req['status'] as String;

          if (status == 'accepted') {
            _friendStatus[senderId] = 'accepted';
          } else if (status == 'pending') {
            _friendStatus[senderId] = 'received'; // Meaning "Request Received"
          }
        }
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
      _errorMessage = 'Error searching users: $e';
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendFriendRequest(String userId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return false;

      await Supabase.instance.client.from('friendships').insert({
        'user_id1': currentUserId,
        'user_id2': userId,
        'status': 'pending',
      });

      _friendStatus[userId] = 'pending';
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      _errorMessage = 'Failed to send request: $e';
      notifyListeners();
      return false;
    }
  }
}
