import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';

class ChatController with ChangeNotifier {
  final String roomId;
  final List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> get messages => _messages;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  RealtimeChannel? _subscription;

  ChatController({required this.roomId}) {
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    debugPrint('ChatController: Initializing for room $roomId');
    // 1. Subscribe FIRST to avoid missing messages between sync and subscribe
    subscribeToMessages();
    // 2. Load local cache
    await loadLocalMessages();
    // 3. Sync from remote
    await syncMessages();
  }

  Future<void> loadLocalMessages() async {
    try {
      final localMsgs = await LocalDatabaseService.getMessages(roomId);
      _messages.clear();
      _messages.addAll(localMsgs);
      debugPrint('ChatController: Loaded ${localMsgs.length} local messages');
    } catch (e) {
      debugPrint('ChatController: Error loading local messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncMessages() async {
    try {
      final lastTimestamp = await LocalDatabaseService.getLastMessageTimestamp(
        roomId,
      );
      debugPrint('ChatController: Syncing from timestamp: $lastTimestamp');

      var query = Supabase.instance.client
          .from('messages')
          .select()
          .eq('room_id', roomId);

      if (lastTimestamp != null) {
        query = query.gt('created_at', lastTimestamp);
      }

      final response = await query.order('created_at', ascending: true);

      if ((response as List).isNotEmpty) {
        final List<Map<String, dynamic>> newMessages =
            List<Map<String, dynamic>>.from(response);
        debugPrint(
          'ChatController: Found ${newMessages.length} new remote messages',
        );
        await LocalDatabaseService.saveMessages(newMessages);

        final updatedMsgs = await LocalDatabaseService.getMessages(roomId);
        _messages.clear();
        _messages.addAll(updatedMsgs);
        notifyListeners();
      } else {
        debugPrint('ChatController: No new remote messages');
      }
    } catch (e) {
      debugPrint('ChatController: Error syncing messages: $e');
    }
  }

  void subscribeToMessages() {
    debugPrint('ChatController: Subscribing to real-time for room $roomId');
    
    // Using a simpler, unique channel name
    _subscription = Supabase.instance.client
        .channel('room-channel:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // Listen to INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            debugPrint('ChatController: Real-time payload received: ${payload.eventType}');
            
            if (payload.eventType == PostgresChangeEvent.insert) {
              final newMessage = payload.newRecord;
              
              // 1. Avoid duplicate if we already added it (either optimistically or via sync)
              final alreadyExists = _messages.any(
                (m) => m['id'].toString() == newMessage['id'].toString(),
              );

              if (!alreadyExists) {
                // 2. Save to local DB for persistence
                try {
                  await LocalDatabaseService.saveMessage(newMessage);
                } catch (e) {
                  debugPrint('ChatController ERR: saving real-time message: $e');
                }
                
                // 3. Add to UI and sort
                _messages.add(Map<String, dynamic>.from(newMessage));
                _sortMessages();
                notifyListeners();
              }
            } else if (payload.eventType == PostgresChangeEvent.update) {
              final updatedRecord = payload.newRecord;
              
              final index = _messages.indexWhere(
                (m) => m['id'].toString() == updatedRecord['id'].toString(),
              );
              
              if (index != -1) {
                _messages[index] = Map<String, dynamic>.from(updatedRecord);
                _sortMessages();
                notifyListeners();
              }
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('ChatController: Real-time status: $status');
          if (error != null) {
            debugPrint('ChatController REALTIME ERR: $error');
          }
        });
  }

  void _sortMessages() {
    // Ensure accurate timing-based ordering
    _messages.sort((a, b) {
      final aTime = DateTime.parse(a['created_at']).toLocal();
      final bTime = DateTime.parse(b['created_at']).toLocal();
      return aTime.compareTo(bTime);
    });
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('ChatController: Cannot send, user not logged in');
        return;
      }

      debugPrint('ChatController: Sending message to room $roomId');

      final response = await Supabase.instance.client
          .from('messages')
          .insert({
            'sender_id': currentUserId,
            'room_id': roomId,
            'content': content.trim(),
          })
          .select()
          .single();

      debugPrint(
        'ChatController: Message sent successfully: ${response['id']}',
      );

      // Optimistically add to UI immediately
      final alreadyExists = _messages.any(
        (m) => m['id'].toString() == response['id'].toString(),
      );
      if (!alreadyExists) {
        _messages.add(Map<String, dynamic>.from(response));
        _sortMessages();
        notifyListeners();
      }

      // Save to local DB
      try {
        await LocalDatabaseService.saveMessage(response);
      } catch (e) {
        debugPrint('ChatController: Error saving sent message locally: $e');
      }
    } catch (e) {
      debugPrint('ChatController: Error sending message: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}
