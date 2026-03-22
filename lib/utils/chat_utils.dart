import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_database_service.dart';
import '../services/encryption_service.dart';

class ChatUtils {
  /// Resolves the chat room ID for the current user and [targetUserId].
  static Future<String?> getOrCreateRoom(String targetUserId) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserId == null) return null;

      final cachedRoomId = await LocalDatabaseService.getUserRoom(targetUserId);

      // ── Try online resolution ──────────────────────────────────────────
      try {
        final response = await Supabase.instance.client
            .rpc('get_or_create_1_1_room', params: {'user1': currentUserId, 'user2': targetUserId})
            .timeout(const Duration(seconds: 8));

        if (response != null) {
          final roomId = response as String;

          // ── E2EE Handshake Mechanism ────────────────────────────────────
          final encryptionReady = await _ensureRoomEncryption(roomId, currentUserId, targetUserId);
          
          if (!encryptionReady) {
             debugPrint('ChatUtils: E2EE Handshake failed. Room unstartable securely.');
             // Optionally return null to block the insecure UI from loading
             return null;
          }

          // Persist so future offline lookups work
          await LocalDatabaseService.saveUserRoom(targetUserId, roomId);
          return roomId;
        }
      } catch (e) {
        debugPrint('ChatUtils: Online resolution/handshake failed: $e');
      }

      // ── Fallback ─────────────────────────────────────────
      if (cachedRoomId != null) {
        // If we fall back to offline, we MUST make sure the key is in memory 
        // otherwise we can't send/receive!
        if (EncryptionService().isInitialized && EncryptionService().isRoomKeyCached(cachedRoomId)) {
           return cachedRoomId;
        }
        // If not cached gracefully try to pull just the participants locally (Wait, offline can't pull keys if app restarted. That's true E2EE offline limitation. If the AES key isn't in memory on cold start offline, you can't read new messages. We'll allow entering the room but they can't decrypt).
        return cachedRoomId;
      }

      return null;
    } catch (e) {
      debugPrint('ChatUtils Error: $e');
      return null;
    }
  }

  /// Ensures that both participants have encrypted room keys in the database and 
  /// that the AES-256 room key is loaded strictly into memory.
  static Future<bool> _ensureRoomEncryption(String roomId, String myUserId, String targetUserId) async {
    final encService = EncryptionService();
    if (!encService.isInitialized) return false;

    // 1. If we already hold the KEK in memory, we are solid.
    if (encService.isRoomKeyCached(roomId)) return true;

    // 2. Fetch the current participants table for this room
    final participantsData = await Supabase.instance.client
        .from('room_participants')
        .select('user_id, encrypted_room_key')
        .eq('room_id', roomId);

    final List<dynamic> records = participantsData;
    String? myEncryptedKeyStr;

    for (var p in records) {
      if (p['user_id'] == myUserId) myEncryptedKeyStr = p['encrypted_room_key'];
    }

    // 3. Scenario A: The Room Key exists, we just need to pull it down and decrypt into RAM
    if (myEncryptedKeyStr != null && myEncryptedKeyStr.isNotEmpty) {
      debugPrint('ChatUtils: Found existing Encrypted Room Key. Decrypting into RAM...');
      try {
        final Map<String, dynamic> payload = jsonDecode(myEncryptedKeyStr);
        // We need OUR public key to derive KEK against OUR private key
        final myPubBase64 = await encService.getPublicKeyBase64();
        if (myPubBase64 == null) return false;

        // Yes! To decrypt OUR copy, the sender was OURSELVES (since the initiator wraps it for both).
        // Wait! In Scenario A, we are loading. What if *they* created the room? Then *they* were the sender.
        // Actually, if someone else wraps it for us, they use their private key and our public key.
        // But if we wrap it for ourselves, we use our private key and our public key.
        // This means we must know WHO wrapped the key. 
        // -------------------------------------------------------------
        // We will pull BOTH public keys to attempt decryption gracefully!
        return await _attemptToDecryptRoomKey(roomId, payload, myUserId, targetUserId, encService);
      } catch (e) {
        debugPrint('ChatUtils Decryption Error: $e');
        return false;
      }
    }

    // 4. Scenario B: Brand New Room (or uninitialized encryption). We must generate and distribute the keys!
    debugPrint('ChatUtils: No existing E2EE keys found. Initiating secure room key generation...');
    
    // Fetch Target's Profile to get their Public Key
    final targetProfile = await Supabase.instance.client
        .from('profiles')
        .select('public_key')
        .eq('id', targetUserId)
        .maybeSingle();

    if (targetProfile == null || targetProfile['public_key'] == null) {
      debugPrint('ChatUtils: Target user has not generated a public key yet. Handshake aborted.');
      // Cannot E2EE chat with someone who hasn't opened the updated app yet.
      return false;
    }

    final targetPubB64 = targetProfile['public_key'] as String;
    final myPubB64 = await encService.getPublicKeyBase64();
    if (myPubB64 == null) return false;

    // Generate Raw Key and Cache it
    final rawAesKey = await encService.generateNewRoomKey();
    encService.cacheRoomKey(roomId, rawAesKey);

    // Encrypt for Target
    final targetEncryptedPayload = await encService.encryptRoomKeyForUser(targetPubB64, rawAesKey);
    // Save who encrypted this (me)
    targetEncryptedPayload['sender_pub'] = myPubB64;

    // Encrypt for Me (I am wrapping it for myself)
    final myEncryptedPayload = await encService.encryptRoomKeyForUser(myPubB64, rawAesKey);
    // Save who encrypted this (me)
    myEncryptedPayload['sender_pub'] = myPubB64;

    // Patch Supabase 
    await Supabase.instance.client
        .from('room_participants')
        .update({'encrypted_room_key': jsonEncode(myEncryptedPayload)})
        .eq('room_id', roomId)
        .eq('user_id', myUserId);
        
    await Supabase.instance.client
        .from('room_participants')
        .update({'encrypted_room_key': jsonEncode(targetEncryptedPayload)})
        .eq('room_id', roomId)
        .eq('user_id', targetUserId);

    debugPrint('ChatUtils: E2EE Secure Handshake Success!');
    return true;
  }

  /// Helper to attempt decrypting the room key by deducing the sender's origin identity
  static Future<bool> _attemptToDecryptRoomKey(
      String roomId, 
      Map<String, dynamic> payload, 
      String myUserId, 
      String targetUserId, 
      EncryptionService encService) async {
      
      // FIX For Bug #1: Always use the 'sender_pub' embedded in the payload if it exists.
      // This protects against the other user rotating their public key in the profiles table!
      if (payload.containsKey('sender_pub')) {
         try {
            final senderPub = payload['sender_pub'] as String;
            final key = await encService.decryptRoomKey(senderPub, payload);
            encService.cacheRoomKey(roomId, key);
            return true;
         } catch (e) {
            debugPrint('Failed to decrypt using explicit sender_pub: $e');
            // If it fails, fallback gracefully to guessing
         }
      }

      final myPubB64 = await encService.getPublicKeyBase64();
      final targetProfile = await Supabase.instance.client.from('profiles').select('public_key').eq('id', targetUserId).maybeSingle();
      final targetPubB64 = targetProfile?['public_key'];

      // Fallback Attempt 1: Did I initiate this room?
      try {
         if (myPubB64 != null) {
            final key = await encService.decryptRoomKey(myPubB64, payload);
            encService.cacheRoomKey(roomId, key);
            return true;
         }
      } catch (e) {
         // Not me.
      }

      // Fallback Attempt 2: Did the target initiate this room?
      if (targetPubB64 != null) {
         try {
            final key = await encService.decryptRoomKey(targetPubB64, payload);
            encService.cacheRoomKey(roomId, key);
            return true;
         } catch (e) {
            // Not them either. Corrupted data.
         }
      }
      return false;
  }
}
