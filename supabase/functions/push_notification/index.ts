import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ─── OAuth Helper: Convert PEM private key string to ArrayBuffer ──────────────
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const binary = atob(base64);
  const buffer = new ArrayBuffer(binary.length);
  const view = new Uint8Array(buffer);
  for (let i = 0; i < binary.length; i++) {
    view[i] = binary.charCodeAt(i);
  }
  return buffer;
}

// ─── OAuth Helper: Base64url encode ───────────────────────────────────────────
function base64url(data: string | ArrayBuffer): string {
  let base64: string;
  if (typeof data === 'string') {
    base64 = btoa(data);
  } else {
    base64 = btoa(String.fromCharCode(...new Uint8Array(data)));
  }
  return base64.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

// ─── OAuth Helper: Generate a signed JWT from Service Account credentials ─────
async function generateServiceAccountJWT(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600, // Token valid for 1 hour
  };

  const headerB64  = base64url(JSON.stringify(header));
  const payloadB64 = base64url(JSON.stringify(payload));
  const toSign     = `${headerB64}.${payloadB64}`;

  // Import the RSA private key using Web Crypto API (no external lib needed)
  const keyBuffer = pemToArrayBuffer(serviceAccount.private_key);
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const encoder   = new TextEncoder();
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    encoder.encode(toSign)
  );

  return `${toSign}.${base64url(signature)}`;
}

// ─── OAuth Helper: Exchange JWT for a short-lived access token ────────────────
async function getOAuthAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const jwt = await generateServiceAccountJWT(serviceAccount);

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();

  if (!tokenResponse.ok) {
    throw new Error(`OAuth token fetch failed: ${JSON.stringify(tokenData)}`);
  }

  return tokenData.access_token as string;
}

// ─── Main Edge Function Handler ───────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    // Supabase Webhook sends the inserted row inside `payload.record`
    // messages table: id, sender_id, content, room_id, created_at
    const { sender_id, content, room_id } = payload.record || payload;

    if (!sender_id || !content || !room_id) {
      console.log('Missing payload fields:', { sender_id, content, room_id });
      return new Response(JSON.stringify({ message: 'Missing payload fields.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // ── Supabase client (Service Role — bypasses RLS) ─────────────────────
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    // 1. Find the receiver: the other participant in the room
    const { data: participants, error: participantsError } = await supabase
      .from('room_participants')
      .select('user_id')
      .eq('room_id', room_id)
      .neq('user_id', sender_id);

    if (participantsError || !participants || participants.length === 0) {
      console.log('No receiver found in room:', room_id);
      return new Response(JSON.stringify({ message: 'No receiver found.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    const receiver_id = participants[0].user_id;

    // 2. Fetch receiver's FCM token from profiles
    const { data: receiverProfile, error: receiverError } = await supabase
      .from('profiles')
      .select('fcm_token')
      .eq('id', receiver_id)
      .single();

    if (receiverError || !receiverProfile?.fcm_token) {
      console.log(`No FCM token for receiver ${receiver_id}. Skipping.`);
      return new Response(JSON.stringify({ message: 'No FCM token for receiver.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // 3. Fetch sender's username for the notification title
    const { data: senderProfile } = await supabase
      .from('profiles')
      .select('username')
      .eq('id', sender_id)
      .single();

    const senderName = senderProfile?.username || 'Someone';

    // 4. Load Firebase Service Account JSON from Supabase Secret
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON environment variable.');
    }

    const serviceAccount = JSON.parse(serviceAccountJson) as Record<string, string>;

    // 5. Generate OAuth 2.0 access token using Service Account JWT flow
    const accessToken = await getOAuthAccessToken(serviceAccount);

    // 6. Protect E2EE Content: Never expose the encrypted JSON payload in the push notification body
    const notificationBody = '🔒 Sent you a new message';

    // 7. Build FCM v1 payload
    const fcmPayload = {
      message: {
        token: receiverProfile.fcm_token,
        notification: {
          title: senderName,
          body: notificationBody,
        },
        data: {
          sender_id: sender_id,
          room_id: room_id,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channel_id: 'high_importance_channel',
          },
        },
      },
    };

    // 8. Send via FCM v1 HTTP API
    const projectId = serviceAccount.project_id;
    const fcmResponse = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      }
    );

    const fcmResult = await fcmResponse.json();
    console.log('FCM v1 Result:', JSON.stringify(fcmResult));

    if (!fcmResponse.ok) {
      throw new Error(`FCM v1 API Error: ${fcmResponse.status} - ${JSON.stringify(fcmResult)}`);
    }

    return new Response(
      JSON.stringify({ success: true, fcm_result: fcmResult }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error) {
    console.error('push_notification error:', error.message);
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
