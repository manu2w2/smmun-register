import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler } from './handler.mjs';

const origin = 'https://panel.example';
const allowedUsers = new Set(['authorized-user']);
let reads = 0;
const handler = createHandler({
  origin, allowedUsers,
  getUser: async (token) => token === 'valid' ? { id: 'authorized-user' }
    : token === 'other' ? { id: 'other-user' }
    : token === 'anonymous' ? { id: 'authorized-user', is_anonymous: true } : null,
  readCatalog: async () => { reads++; return { representations: [], runs: [] }; },
});
const request = (token, method = 'GET', site = origin) => new Request('https://example.test', {
  method, headers: { origin: site, ...(token ? { authorization: 'Bearer ' + token } : {}) },
});

test('solo permite usuarios explícitamente autorizados', async () => {
  reads = 0;
  assert.equal((await handler(request(''))).status, 401);
  assert.equal((await handler(request('invalid'))).status, 401);
  assert.equal((await handler(request('other'))).status, 401);
  assert.equal((await handler(request('anonymous'))).status, 401);
  assert.equal((await handler(request('valid', 'POST'))).status, 405);
  assert.equal((await handler(request('valid', 'GET', 'https://other.example'))).status, 403);
  assert.equal(reads, 0);
  const result = await handler(request('valid'));
  assert.equal(result.status, 200);
  assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.deepEqual(await result.json(), { representations: [], runs: [] });
  assert.equal(reads, 1);
});
test('permite preflight solo al origen configurado y falla cerrado ante errores', async () => {
  assert.equal((await handler(request('', 'OPTIONS'))).status, 204);
  assert.equal((await handler(request('', 'OPTIONS', 'https://other.example'))).status, 403);
  const failing = createHandler({ origin, allowedUsers, getUser: async () => { throw new Error('offline'); }, readCatalog: async () => { throw new Error('not called'); } });
  assert.equal((await failing(request('valid'))).status, 503);
  const databaseDown = createHandler({ origin, allowedUsers, getUser: async () => ({ id: 'authorized-user' }), readCatalog: async () => { throw new Error('offline'); } });
  const result = await databaseDown(request('valid'));
  assert.equal(result.status, 503);
  assert.deepEqual(await result.json(), { error: 'unavailable' });
});
