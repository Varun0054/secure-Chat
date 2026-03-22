import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../utils/chat_utils.dart';
import '../services/local_database_service.dart';
import '../services/encryption_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class DashboardController with ChangeNotifier {
  String? _username;
  String? get username => _username;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> get friends => _friends;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;

  Future<void> loadLocalData() async {
    try {
      final cachedUsername = await LocalDatabaseService.getCacheString('current_username');
      if (cachedUsername != null && cachedUsername.isNotEmpty) {
        _username = cachedUsername;
      }

      final cachedFriendsStr = await LocalDatabaseService.getCacheString('cached_friends');
      if (cachedFriendsStr != null && cachedFriendsStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedFriendsStr);
        _friends = List<Map<String, dynamic>>.from(decoded);
      }

      final cachedPendingStr = await LocalDatabaseService.getCacheString('cached_pending');
      if (cachedPendingStr != null && cachedPendingStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedPendingStr);
        _pendingRequests = List<Map<String, dynamic>>.from(decoded);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading local local data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserProfile() async {
    // 0. Initialize Encryption Service (Identity Persistence)
    try {
      await EncryptionService().initialize();
    } catch (e) {
      debugPrint('Error initializing EncryptionService: $e');
    }

    // 1. Source of Truth: Always load local database first
    await loadLocalData();

    // 1.5 Sync Public Key to Supabase if not offline
    await _syncPublicKey();

    // 2. Background Sync (Network)
    await _syncNetworkData();

    // 3. Setup FCM Token Generation
    await _setupFCMToken();

    // 4. Setup Global Message Status Listener (for 'delivered' status)
    _setupGlobalMessageListener();
  }

  Future<void> _syncPublicKey() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || !EncryptionService().isInitialized) return;

      final publicKeyB64 = await EncryptionService().getPublicKeyBase64();
      if (publicKeyB64 != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'public_key': publicKeyB64})
            .eq('id', user.id);
        debugPrint('Dashboard: Synced E2EE Public Key to Supabase.');
      }
    } catch (e) {
      debugPrint('Dashboard: Failed to sync public key (offline?): $e');
    }
  }

  Future<void> _setupFCMToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Ask user permission before fetching token
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM: User granted permission');

        // Generate FCM Token using getToken()
        String? token = await messaging.getToken();

        final savedToken = await LocalDatabaseService.getCacheString('fcm_token');

        if (token != null && token != savedToken) {
          debugPrint('FCM Token: $token');

          // Ensure user is logged in before saving logic
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
             try {
                // Store the FCM token in Supabase linked to user ID
                await Supabase.instance.client
                  .from('profiles')
                  .update({'fcm_token': token})
                  .eq('id', user.id);
                
                await LocalDatabaseService.saveCacheString('fcm_token', token);
                debugPrint('FCM Token successfully stored in Supabase');
             } catch (e) {
                debugPrint('FCM Token Supabase update failed: $e');
             }
          }
        } else if (token != null) {
          debugPrint('FCM Token unchanged, skipping update');
        } else {
          // Handle null token safely
          debugPrint('FCM Token is null');
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) async {
          debugPrint('FCM Token Refreshed: $newToken');
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            try {
              await Supabase.instance.client
                  .from('profiles')
                  .update({'fcm_token': newToken})
                  .eq('id', user.id);
              
              await LocalDatabaseService.saveCacheString('fcm_token', newToken);
              debugPrint('Refreshed FCM Token stored successfully');
            } catch (e) {
              debugPrint('Failed to update refreshed token: $e');
            }
          }
        });

        // onMessageOpenedApp: fires when user taps a notification while app is backgrounded
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint("User clicked notification: ${message.notification?.title}");
          // TODO: Navigate to the specific chat room based on message.data['sender_id']
        });

      } else {
        // Handle permission denial gracefully
        debugPrint('FCM: User declined or has not accepted permission');
      }
    } catch (e) {
      debugPrint('Error setting up FCM: $e');
    }
  }

  Future<void> _syncNetworkData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // Wrap in independent try-catches so one failure doesn't bypass the rest
      try {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 10)); // Timeout prevents infinite hanging

        if (profileData != null) {
          _username = profileData['username'] as String?;
          if (_username != null) {
             await LocalDatabaseService.saveCacheString('current_username', _username!);
          }
        }
        _isOffline = false; // Network call succeeded
      } catch (e) {
        debugPrint('Profile sync failed (offline?): $e');
        _isOffline = true;
      }

      // Always try syncing friends and requests regardless of profile sync success
      await fetchFriends();
      await fetchPendingRequests();

    } catch (e) {
      debugPrint('Fatal error in sync network data: $e');
      _isOffline = true;
    } finally {
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
          .eq('status', 'accepted')
          .timeout(const Duration(seconds: 10));

      final received = await Supabase.instance.client
          .from('friendships')
          .select('user_id1, profiles:user_id1(id, username, email)')
          .eq('user_id2', user.id)
          .eq('status', 'accepted')
          .timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> updatedFriends = [];
      for (var item in sent) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        if (profile != null) updatedFriends.add(profile);
      }
      for (var item in received) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        if (profile != null) updatedFriends.add(profile);
      }

      // Successfully synced: Update Cache
      _friends = updatedFriends;
      _isOffline = false;
      await LocalDatabaseService.saveCacheString('cached_friends', jsonEncode(_friends));
      notifyListeners();

    } catch (e) {
      debugPrint('Friends sync failed (offline?): $e');
      _isOffline = true;
      notifyListeners();
    }
  }

  Future<void> fetchPendingRequests() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('friendships')
          .select('id, user_id1, profiles:user_id1(id, username, email)')
          .eq('user_id2', user.id)
          .eq('status', 'pending')
          .timeout(const Duration(seconds: 10));

      _pendingRequests = List<Map<String, dynamic>>.from(data);
      _isOffline = false;
      await LocalDatabaseService.saveCacheString('cached_pending', jsonEncode(_pendingRequests));
      notifyListeners();

    } catch (e) {
      debugPrint('Pending requests sync failed (offline?): $e');
       _isOffline = true;
      notifyListeners();
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
    // If offline, try checking if room exists locally via query or ChatUtils
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

  void _setupGlobalMessageListener() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    debugPrint('DashboardController: Setting up global message status listener');
    
    Supabase.instance.client
        .channel('global-messages-service')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final message = payload.newRecord;
            if (message['sender_id'] != user.id && message['status'] == 'sent') {
                debugPrint('GlobalListener: Marking message ${message['id']} as delivered');
                try {
                  await Supabase.instance.client
                      .from('messages')
                      .update({
                        'status': 'delivered', 
                        'delivered_at': DateTime.now().toIso8601String()
                      })
                      .eq('id', message['id']);
                } catch (e) {
                  debugPrint('GlobalListener ERR: $e');
                }
            }
          },
        )
        .subscribe();
  }

  Future<void> logout(BuildContext context) async {
    await LocalDatabaseService.clearAll(); // Clear caches
    await EncryptionService().deletePersistentIdentity(); // Clear cryptographic identity
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }
}
