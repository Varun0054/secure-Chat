import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';

class ChatUtils {
  /// Resolves the chat room ID for the current user and [targetUserId].
  ///
  /// Strategy (offline-first):
  ///   1. Try to get a cached room ID from the local SQLite DB.
  ///   2. If online, call the Supabase RPC to get/create the room and cache it.
  ///   3. If offline and no local cache exists, return null.
  static Future<String?> getOrCreateRoom(String targetUserId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) {
        debugPrint('ChatUtils: currentUserId is null');
        return null;
      }

      debugPrint(
        'ChatUtils: Resolving room for $currentUserId and $targetUserId',
      );

      // ── 1. Check local cache first ────────────────────────────────────────
      final cachedRoomId =
          await LocalDatabaseService.getUserRoom(targetUserId);

      // ── 2. Try online resolution ──────────────────────────────────────────
      try {
        final response = await Supabase.instance.client
            .rpc(
              'get_or_create_1_1_room',
              params: {'user1': currentUserId, 'user2': targetUserId},
            )
            .timeout(const Duration(seconds: 8));

        if (response != null) {
          final roomId = response as String;
          debugPrint('ChatUtils: Room resolved online: $roomId');

          // Persist so future offline lookups work
          await LocalDatabaseService.saveUserRoom(targetUserId, roomId);
          return roomId;
        }
      } catch (e) {
        // Network unavailable or timeout — fall through to local cache
        debugPrint('ChatUtils: Online resolution failed (offline?): $e');
      }

      // ── 3. Fallback to local cache ─────────────────────────────────────────
      if (cachedRoomId != null) {
        debugPrint('ChatUtils: Using cached room offline: $cachedRoomId');
        return cachedRoomId;
      }

      debugPrint('ChatUtils: No room found locally or remotely');
      return null;
    } catch (e) {
      debugPrint('ChatUtils Error: $e');
      return null;
    }
  }
}
