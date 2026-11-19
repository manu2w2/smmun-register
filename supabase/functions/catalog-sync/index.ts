import postgres from 'npm:postgres@3.4.7';
import { GoogleAuth } from 'npm:google-auth-library@9.15.1';
import { getSheetRows, SyncError } from './catalog.mjs';

function setting(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new SyncError('configuration');
  return value;
}
async function authorized(request: Request, secret: string) {
  const provided = request.headers.get('x-catalog-sync-secret') ?? '';
  const digest = async (s: string) => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)));
  const [a, b] = await Promise.all([digest(provided), digest(secret)]);
  return a.reduce((difference, byte, index) => difference | (byte ^ b[index]), 0) === 0;
}
Deno.serve(async (request) => {
  if (request.method !== 'POST') return new Response('Método no permitido', { status: 405 });
  let secret: string;
  try { secret = setting('CATALOG_SYNC_SECRET'); } catch { return new Response('Configuración incompleta', { status: 503 }); }
  if (!await authorized(request, secret)) return new Response('No autorizado', { status: 401 });

  let sql: ReturnType<typeof postgres> | undefined;
  let runId: string | undefined;
  let edition = '';
  let locked = false;
  const metrics = { attempts: 0, rate_limited: 0 };
  try {
    edition = setting('CATALOG_EDITION');
    const mode = setting('CATALOG_MODE');
    const spreadsheet = setting('CATALOG_SPREADSHEET_ID');
    const sheet = setting('CATALOG_SHEET_ID');
    const project = setting('CATALOG_GOOGLE_PROJECT_KEY');
    if (!/^[a-z0-9][a-z0-9-]{0,63}$/.test(edition) || !/^\d+$/.test(sheet) || !['preview', 'apply'].includes(mode)) throw new SyncError('configuration');
    const credentials = JSON.parse(setting('GOOGLE_SERVICE_ACCOUNT_JSON'));
    if (!credentials.client_email || !credentials.private_key) throw new SyncError('configuration');
    sql = postgres(setting('CATALOG_DATABASE_URL'), { max: 1, prepare: false, idle_timeout: 0, connect_timeout: 10 });
    const lock = await sql`select pg_backend_pid() as pid, pg_try_advisory_lock(hashtextextended(${'catalog.representations:' + edition}, 0)) as locked`;
    locked = lock[0].locked;
    const backendPid = lock[0].pid;
    if (locked) {
      await sql`update catalog.sync_runs set status='error', finished_at=now(), error_code='interrupted'
        where edition=${edition} and status='running' and started_at < now() - interval '5 minutes'`;
    }
    const started = await sql`insert into catalog.sync_runs (edition, mode, status, finished_at)
      values (${edition}, ${mode}, ${locked ? 'running' : 'skipped'}, case when ${locked} then null else now() end) returning id`;
    runId = started[0].id;
    if (!locked) return Response.json({ status: 'skipped' });
    const auth = new GoogleAuth({ credentials, scopes: ['https://www.googleapis.com/auth/spreadsheets.readonly'] });
    const access = await Promise.race([
      auth.getAccessToken(),
      new Promise<never>((_, reject) => setTimeout(() => reject(new SyncError('google_auth_timeout')), 15000)),
    ]);
    if (!access) throw new SyncError('google_auth');
    const reserve = async () => {
      const result = await sql!`select pg_backend_pid() as pid, catalog.reserve_sheet_read(${project}) as allowed`;
      if (result[0].pid !== backendPid) throw new SyncError('connection_lost');
      return result[0].allowed;
    };
    const rows = await getSheetRows(spreadsheet, Number(sheet), access, reserve, metrics);
    const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(rows)));
    const hash = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
    const preview = await sql`select catalog.import_representations(${edition}, ${sql.json(rows)}, false, false) as report`;
    let report = preview[0].report;
    const status = report.ausentes > 0 ? 'review' : 'success';
    await sql.begin(async (tx) => {
      const session = await tx`select pg_backend_pid() as pid`;
      if (session[0].pid !== backendPid) throw new SyncError('connection_lost');
      if (mode === 'apply' && status === 'success') {
        const result = await tx`select catalog.import_representations(${edition}, ${tx.json(rows)}, true, false) as report`;
        report = result[0].report;
      }
      await tx`update catalog.sync_runs set status=${status}, finished_at=now(), source_hash=${hash},
        altas=${report.altas}, cambios=${report.cambios}, iguales=${report.iguales}, ausentes=${report.ausentes},
        attempts=${metrics.attempts}, rate_limited=${metrics.rate_limited} where id=${runId}`;
    });
    return Response.json({ status, altas: report.altas, cambios: report.cambios, iguales: report.iguales, ausentes: report.ausentes });
  } catch (error) {
    const code = error instanceof SyncError ? error.code : 'sync_error';
    if (sql && runId) {
      // Si la confirmación de COMMIT se perdió, la transacción pudo haber
      // terminado correctamente. Conserva el resultado ya confirmado.
      try { await sql`update catalog.sync_runs set status='error', finished_at=now(), error_code=${code},
        attempts=${metrics.attempts}, rate_limited=${metrics.rate_limited}
        where id=${runId} and status='running'`; } catch { /* El estado será revisado por caducidad. */ }
    }
    return Response.json({ status: 'error', code }, { status: 500 });
  } finally {
    if (sql) {
      if (locked) {
        try { await sql`select pg_advisory_unlock(hashtextextended(${'catalog.representations:' + edition}, 0))`; } catch { /* El cierre libera el bloqueo. */ }
      }
      await sql.end({ timeout: 2 });
    }
  }
});
