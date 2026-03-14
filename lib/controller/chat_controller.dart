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
    await loadLocalMessages();
    await syncMessages();
    subscribeToMessages();
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
    _subscription = Supabase.instance.client
        .channel('public:messages:room:$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) async {
            final newMessage = payload.newRecord;
            debugPrint(
              'ChatController: Real-time message received: ${newMessage['id']}',
            );

            // Avoid duplicate if we already added it optimistically
            final alreadyExists = _messages.any(
              (m) => m['id'] == newMessage['id'],
            );
            if (!alreadyExists) {
              try {
                await LocalDatabaseService.saveMessage(newMessage);
              } catch (e) {
                debugPrint(
                  'ChatController: Error saving real-time message locally: $e',
                );
              }
              _messages.add(newMessage);
              notifyListeners();
            }
          },
        )
        .subscribe();
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
      final alreadyExists = _messages.any((m) => m['id'] == response['id']);
      if (!alreadyExists) {
        _messages.add(Map<String, dynamic>.from(response));
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
