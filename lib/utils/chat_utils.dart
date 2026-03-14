import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatUtils {
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

      // Use the consolidated RPC to find or create the room atomically.
      // This bypasses RLS restrictions and ensures both participants are added.
      final response = await Supabase.instance.client.rpc(
        'get_or_create_1_1_room',
        params: {'user1': currentUserId, 'user2': targetUserId},
      );

      if (response != null) {
        debugPrint('ChatUtils: Room resolved: $response');
        return response as String;
      }

      debugPrint('ChatUtils: RPC returned null result');
      return null;
    } catch (e) {
      debugPrint('ChatUtils Error: $e');
      return null;
    }
  }
}
