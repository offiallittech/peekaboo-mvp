export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  return null;
}

export async function readJson<T = Record<string, unknown>>(req: Request): Promise<T> {
  try {
    return await req.json() as T;
  } catch {
    return {} as T;
  }
}

export function getBearerToken(req: Request): string | null {
  const auth = req.headers.get("Authorization") ?? "";
  return auth.startsWith("Bearer ") ? auth.slice(7) : null;
}

export async function getAuthUserId(req: Request): Promise<string | null> {
  const token = getBearerToken(req);
  if (!token) return null;

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return null;

  const resp = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: anonKey,
    },
  });
  if (!resp.ok) return null;
  const user = await resp.json();
  return typeof user?.id === "string" ? user.id : null;
}

export async function supabaseRest(path: string, init: RequestInit = {}): Promise<Response> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }

  return fetch(`${supabaseUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceRoleKey,
      Authorization: `Bearer ${serviceRoleKey}`,
      "Content-Type": "application/json",
      Prefer: "return=representation",
      ...(init.headers ?? {}),
    },
  });
}

export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .match(/[a-z']+/g)?.map((w) => w.replace(/^'+|'+$/g, "")).filter(Boolean) ?? [];
}
