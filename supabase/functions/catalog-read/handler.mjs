export function createHandler({ origin, allowedUsers, getUser, readCatalog }) {
  const headers = {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
    'Cache-Control': 'no-store',
    'Vary': 'Origin',
    'X-Content-Type-Options': 'nosniff',
  };
  const response = (body, status) => Response.json(body, { status, headers });
  return async (request) => {
    const requestOrigin = request.headers.get('origin');
    if (requestOrigin && requestOrigin !== origin) return new Response(null, { status: 403 });
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
    if (request.method !== 'GET') return response({ error: 'method_not_allowed' }, 405);
    const auth = request.headers.get('authorization') ?? '';
    if (!/^Bearer \S+$/i.test(auth)) return response({ error: 'unauthorized' }, 401);
    try {
      const user = await getUser(auth.slice(7));
      if (!user || user.is_anonymous || !allowedUsers.has(user.id)) {
        return response({ error: 'unauthorized' }, 401);
      }
      return response(await readCatalog(), 200);
    } catch {
      return response({ error: 'unavailable' }, 503);
    }
  };
}
