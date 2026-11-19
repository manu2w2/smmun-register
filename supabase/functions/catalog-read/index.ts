import postgres from 'npm:postgres@3.4.7';
import { createHandler } from './handler.mjs';

function setting(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error('configuration');
  return value;
}

try {
  const origin = setting('CATALOG_PANEL_ORIGIN');
  const originUrl = new URL(origin);
  if (originUrl.origin !== origin || (originUrl.protocol !== 'https:' &&
      !(originUrl.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(originUrl.hostname)))) {
    throw new Error('configuration');
  }
  const allowedUsers = new Set(setting('CATALOG_PANEL_ALLOWED_USER_IDS').split(',').map((id) => id.trim()));
  if ([...allowedUsers].some((id) => !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id))) {
    throw new Error('configuration');
  }
  const supabaseUrl = setting('SUPABASE_URL').replace(/\/$/, '');
  const anonKey = setting('SUPABASE_ANON_KEY');
  const databaseUrl = setting('CATALOG_VIEWER_DATABASE_URL');
  const getUser = async (token: string) => {
    const result = await fetch(supabaseUrl + '/auth/v1/user', {
      headers: { apikey: anonKey, authorization: 'Bearer ' + token },
      signal: AbortSignal.timeout(10000),
    });
    if (result.status === 401 || result.status === 403) return null;
    if (!result.ok) throw new Error('auth_unavailable');
    return result.json();
  };
  const readCatalog = async () => {
    const sql = postgres(databaseUrl, { max: 1, prepare: false, connect_timeout: 10 });
    try {
      return await sql.begin(async (tx) => {
        await tx.unsafe('set transaction read only');
        await tx.unsafe('set local role catalog_viewer');
        const [result] = await tx.unsafe([
          "select jsonb_build_object(",
          "  'representations', coalesce((",
          "    select jsonb_agg(to_jsonb(r) order by r.edition, r.committee, r.representation_name)",
          "    from catalog.representations r",
          "  ), '[]'::jsonb),",
          "  'runs', coalesce((",
          "    select jsonb_agg(to_jsonb(recent) order by started_at desc)",
          "    from (",
          "      (select distinct on (edition) id, edition, mode, status, started_at, finished_at,",
          "        altas, cambios, iguales, ausentes, error_code from catalog.sync_runs",
          "        order by edition, started_at desc)",
          "      union",
          "      (select distinct on (edition) id, edition, mode, status, started_at, finished_at,",
          "        altas, cambios, iguales, ausentes, error_code from catalog.sync_runs",
          "        where mode = 'apply' and status = 'success' order by edition, started_at desc)",
          "    ) recent",
          "  ), '[]'::jsonb)",
          ") as catalog",
        ].join('\n'));
        return result.catalog;
      });
    } finally {
      await sql.end({ timeout: 2 });
    }
  };
  Deno.serve(createHandler({ origin, allowedUsers, getUser, readCatalog }));
} catch {
  Deno.serve(() => Response.json({ error: 'configuration' }, { status: 503 }));
}
