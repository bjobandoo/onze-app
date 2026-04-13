// Edge Function: send-notification
// Envía notificaciones push FCM según el tipo de evento.
// Requiere en env: FIREBASE_PROJECT_ID, FIREBASE_CLIENT_EMAIL, FIREBASE_PRIVATE_KEY
//                  SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const FIREBASE_PROJECT_ID = Deno.env.get('FIREBASE_PROJECT_ID') ?? '';
const FIREBASE_CLIENT_EMAIL = Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? '';
// Las variables de Supabase escapan los \n como \\n — los reemplazamos para que la clave PEM sea válida.
const FIREBASE_PRIVATE_KEY = (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replace(/\\n/g, '\n');

// ---------------------------------------------------------------------------
// OAuth2 — obtener access token para FCM v1
// ---------------------------------------------------------------------------

let _cachedToken: string | null = null;
let _tokenExpiry = 0;

async function getFcmAccessToken(): Promise<string> {
  const now = Date.now();
  if (_cachedToken && now < _tokenExpiry - 60_000) return _cachedToken;

  // JWT header + payload
  const header = { alg: 'RS256', typ: 'JWT' };
  const iat = Math.floor(now / 1000);
  const payload = {
    iss: FIREBASE_CLIENT_EMAIL,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat,
    exp: iat + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const signingInput = `${encode(header)}.${encode(payload)}`;

  // Importar clave privada RSA
  const keyData = FIREBASE_PRIVATE_KEY
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');

  const binaryKey = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  // Firmar
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const jwt = `${signingInput}.${sigB64}`;

  // Intercambiar JWT por access token
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const json = await res.json() as { access_token: string; expires_in: number };
  _cachedToken = json.access_token;
  _tokenExpiry = now + json.expires_in * 1000;
  return _cachedToken;
}

// ---------------------------------------------------------------------------
// Envío de notificación individual (FCM v1)
// ---------------------------------------------------------------------------

async function sendFcm(
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  if (!FIREBASE_PROJECT_ID) return;

  const accessToken = await getFcmAccessToken();

  await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: 'high' },
          apns: {
            payload: { aps: { sound: 'default', badge: 1 } },
            headers: { 'apns-priority': '10' },
          },
        },
      }),
    },
  );
}

async function notifyUsers(
  userIds: string[],
  title: string,
  body: string,
  data: Record<string, string> = {},
): Promise<void> {
  if (!FIREBASE_PROJECT_ID || userIds.length === 0) return;

  const { data: users } = await supabase
    .from('users')
    .select('id, fcm_token')
    .in('id', userIds)
    .not('fcm_token', 'is', null);

  if (!users?.length) return;

  await Promise.allSettled(
    users.map((u: { fcm_token: string }) =>
      sendFcm(u.fcm_token, title, body, data),
    ),
  );
}

async function getTeamCaptain(teamId: string): Promise<string | null> {
  const { data } = await supabase
    .from('teams')
    .select('captain_id')
    .eq('id', teamId)
    .single();
  return data?.captain_id ?? null;
}

// ---------------------------------------------------------------------------
// Handlers por evento
// ---------------------------------------------------------------------------

async function handleChallengeReceived(matchRequestId: string) {
  const { data: mr } = await supabase
    .from('match_requests')
    .select('challenged_team_id, field_id, challenger_team_id')
    .eq('id', matchRequestId)
    .single();
  if (!mr) return;

  const [captainId, challengerName, fieldName] = await Promise.all([
    getTeamCaptain(mr.challenged_team_id),
    supabase.from('teams').select('name').eq('id', mr.challenger_team_id).single()
      .then((r) => r.data?.name ?? 'Un equipo'),
    supabase.from('fields').select('name').eq('id', mr.field_id).single()
      .then((r) => r.data?.name ?? 'una cancha'),
  ]);

  if (!captainId) return;
  await notifyUsers(
    [captainId],
    '¡Nuevo desafío! ⚽',
    `${challengerName} te desafía en ${fieldName}`,
    { screen: '/matches' },
  );
}

async function handleChallengeAccepted(matchRequestId: string) {
  const { data: mr } = await supabase
    .from('match_requests')
    .select('challenger_team_id, challenged_team_id, field_id')
    .eq('id', matchRequestId)
    .single();
  if (!mr) return;

  const [challengerCaptain, challengedName, fieldData] = await Promise.all([
    getTeamCaptain(mr.challenger_team_id),
    supabase.from('teams').select('name').eq('id', mr.challenged_team_id).single()
      .then((r) => r.data?.name ?? 'Tu rival'),
    supabase.from('fields').select('owner_id, name').eq('id', mr.field_id).single()
      .then((r) => r.data),
  ]);

  const targets = [challengerCaptain, fieldData?.owner_id].filter(Boolean) as string[];
  await notifyUsers(
    targets,
    '¡Desafío aceptado!',
    `${challengedName} aceptó. Esperando confirmación del dueño de ${fieldData?.name ?? 'la cancha'}.`,
    { screen: '/matches' },
  );
}

async function handleChallengeRejected(matchRequestId: string) {
  const { data: mr } = await supabase
    .from('match_requests')
    .select('challenger_team_id, challenged_team_id')
    .eq('id', matchRequestId)
    .single();
  if (!mr) return;

  const [challengerCaptain, challengedName] = await Promise.all([
    getTeamCaptain(mr.challenger_team_id),
    supabase.from('teams').select('name').eq('id', mr.challenged_team_id).single()
      .then((r) => r.data?.name ?? 'El equipo rival'),
  ]);

  if (!challengerCaptain) return;
  await notifyUsers(
    [challengerCaptain],
    'Desafío rechazado',
    `${challengedName} no aceptó tu desafío.`,
    { screen: '/matches' },
  );
}

async function handleMatchConfirmed(matchRequestId: string) {
  const { data: mr } = await supabase
    .from('match_requests')
    .select('challenger_team_id, challenged_team_id, field_id, requested_date, requested_start_time')
    .eq('id', matchRequestId)
    .single();
  if (!mr) return;

  const [captain1, captain2, fieldName] = await Promise.all([
    getTeamCaptain(mr.challenger_team_id),
    getTeamCaptain(mr.challenged_team_id),
    supabase.from('fields').select('name').eq('id', mr.field_id).single()
      .then((r) => r.data?.name ?? 'la cancha'),
  ]);

  const targets = [captain1, captain2].filter(Boolean) as string[];
  const timeStr = (mr.requested_start_time as string).substring(0, 5);
  await notifyUsers(
    targets,
    '¡Partido confirmado! ⚽',
    `${fieldName} · ${mr.requested_date} a las ${timeStr}`,
    { screen: '/matches' },
  );
}

async function handleMatchRejectedOwner(matchRequestId: string) {
  const { data: mr } = await supabase
    .from('match_requests')
    .select('challenger_team_id, challenged_team_id, field_id')
    .eq('id', matchRequestId)
    .single();
  if (!mr) return;

  const [captain1, captain2, fieldName] = await Promise.all([
    getTeamCaptain(mr.challenger_team_id),
    getTeamCaptain(mr.challenged_team_id),
    supabase.from('fields').select('name').eq('id', mr.field_id).single()
      .then((r) => r.data?.name ?? 'la cancha'),
  ]);

  const targets = [captain1, captain2].filter(Boolean) as string[];
  await notifyUsers(
    targets,
    'Reserva no disponible',
    `El dueño de ${fieldName} no pudo confirmar la reserva.`,
    { screen: '/matches' },
  );
}

async function handleTeamInvitation(teamId: string, targetUserId: string) {
  const { data: team } = await supabase
    .from('teams')
    .select('name')
    .eq('id', teamId)
    .single();

  await notifyUsers(
    [targetUserId],
    '¡Nueva invitación!',
    `Te han invitado al equipo "${team?.name ?? 'un equipo'}"`,
    { screen: '/teams/invitations' },
  );
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { event, entityId, extra } = body as {
    event: string;
    entityId?: string;
    extra?: Record<string, string>;
  };

  try {
    switch (event) {
      case 'challenge_received':
        await handleChallengeReceived(entityId!);
        break;
      case 'challenge_accepted':
        await handleChallengeAccepted(entityId!);
        break;
      case 'challenge_rejected':
        await handleChallengeRejected(entityId!);
        break;
      case 'match_confirmed':
        await handleMatchConfirmed(entityId!);
        break;
      case 'match_rejected_owner':
        await handleMatchRejectedOwner(entityId!);
        break;
      case 'team_invitation':
        await handleTeamInvitation(entityId!, extra?.['targetUserId'] ?? '');
        break;
      default:
        return new Response(
          JSON.stringify({ error: `Unknown event: ${event}` }),
          { status: 400, headers: { 'Content-Type': 'application/json' } },
        );
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    console.error('send-notification error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
