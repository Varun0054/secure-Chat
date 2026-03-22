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
    // 1. Load local cache first — makes UI ready immediately (offline-safe)
    await loadLocalMessages();
    // 2. Subscribe to real-time updates (no-op if offline)
    subscribeToMessages();
    // 3. Sync from remote (skipped gracefully if offline)
    await syncMessages();
    // 4. Mark unread messages as read (skipped gracefully if offline)
    await markMessagesAsRead();
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

      final response = await query
          .order('created_at', ascending: true)
          .timeout(const Duration(seconds: 10));

      if ((response as List).isNotEmpty) {
        final List<Map<String, dynamic>> newMessages =
            List<Map<String, dynamic>>.from(response);
        debugPrint(
          'ChatController: Found ${newMessages.length} new remote messages',
        );

        // Scan for messages sent to me that are still 'sent' and mark them delivered
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        for (var msg in newMessages) {
          if (msg['sender_id'] != currentUserId && msg['status'] == 'sent') {
            markMessageAsDelivered(msg);
          }
        }

        await LocalDatabaseService.saveMessages(newMessages);

        final updatedMsgs = await LocalDatabaseService.getMessages(roomId);
        _messages.clear();
        _messages.addAll(updatedMsgs);
        notifyListeners();
      } else {
        debugPrint('ChatController: No new remote messages');
      }
    } catch (e) {
      // Offline or timeout — local messages are already shown, so this is fine
      debugPrint('ChatController: Sync skipped (offline?): $e');
    }
  }

  void subscribeToMessages() {
    debugPrint('ChatController: Subscribing to real-time for room $roomId');
    try {
      _subscription = Supabase.instance.client
          .channel('room-channel:$roomId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'room_id',
              value: roomId,
            ),
            callback: (payload) async {
              debugPrint('ChatController: Real-time payload: ${payload.eventType}');

              if (payload.eventType == PostgresChangeEvent.insert) {
                final newMessage = payload.newRecord;
                final currentUserId =
                    Supabase.instance.client.auth.currentUser?.id;

                // If I am the receiver and on screen, mark as read directly
                if (newMessage['sender_id'] != currentUserId &&
                    newMessage['status'] != 'read') {
                  markMessageAsReadIndividual(newMessage['id']);
                } else if (newMessage['sender_id'] != currentUserId &&
                    newMessage['status'] == 'sent') {
                  // If I'm receive but not marking as read, at least mark delivered
                  markMessageAsDelivered(newMessage);
                }

                final alreadyExists = _messages.any(
                  (m) => m['id'].toString() == newMessage['id'].toString(),
                );

                if (!alreadyExists) {
                  try {
                    await LocalDatabaseService.saveMessage(newMessage);
                  } catch (e) {
                    debugPrint('ChatController ERR: saving real-time message: $e');
                  }

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
                  // Perform a partial update to avoid losing fields if payload is incomplete
                  final Map<String, dynamic> existingMsg =
                      Map<String, dynamic>.from(_messages[index]);
                  existingMsg.addAll(Map<String, dynamic>.from(updatedRecord));
                  _messages[index] = existingMsg;

                  try {
                    await LocalDatabaseService.saveMessage(existingMsg);
                  } catch (e) {
                    debugPrint('ChatController ERR: saving update to local: $e');
                  }

                  _sortMessages();
                  notifyListeners();
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      // Offline — subscription silently skipped; local messages are shown
      debugPrint('ChatController: Real-time subscription failed (offline?): $e');
    }
  }

  Future<void> markMessagesAsRead() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Update in Supabase
      await Supabase.instance.client
          .from('messages')
          .update({
            'status': 'read',
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId)
          .neq('sender_id', currentUserId)
          .neq('status', 'read');

      debugPrint('ChatController: Marked messages as read in room $roomId');
    } catch (e) {
      debugPrint('ChatController: Error marking messages as read: $e');
    }
  }

  Future<void> markMessageAsReadIndividual(String messageId) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'status': 'read',
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId);
      
      debugPrint('ChatController: Marked individual msg $messageId as read');
    } catch (e) {
      debugPrint('ChatController: Error marking single message read: $e');
    }
  }

  Future<void> markMessageAsDelivered(Map<String, dynamic> message) async {
    try {
      await Supabase.instance.client
          .from('messages')
          .update({
            'status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', message['id']);
      
      debugPrint('ChatController: Marked message ${message['id']} as delivered');
    } catch (e) {
      debugPrint('ChatController: Error marking message delivered: $e');
    }
  }

  void _sortMessages() {
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
      if (currentUserId == null) return;

      final response = await Supabase.instance.client
          .from('messages')
          .insert({
            'sender_id': currentUserId,
            'room_id': roomId,
            'content': content.trim(),
            'status': 'sent',
          })
          .select()
          .single();

      final alreadyExists = _messages.any(
        (m) => m['id'].toString() == response['id'].toString(),
      );
      if (!alreadyExists) {
        _messages.add(Map<String, dynamic>.from(response));
        _sortMessages();
        notifyListeners();
      }

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
