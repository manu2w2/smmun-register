import { test } from 'node:test';
import assert from 'node:assert/strict';
import { normalizeRows, getSheetRows, readGoogle } from './catalog.mjs';

const headers = ['comite', 'nombre_delegacion', 'tipo_delegacion', 'permite_codelegacion'];
test('normaliza hojas como el CSV y admite casillas, blancos y cabeceras reordenadas', () => {
  const values = [
    ['tipo_delegacion', 'comite', 'permite_codelegacion', 'nombre_delegacion'],
    ['País', ' Comité ', true, 'A\u0301guila'],
    [],
    ['Persona', 'Otro', 'NO', 'Aurora'],
  ];
  assert.deepEqual(normalizeRows(values), [
    { source_line: 2, committee: 'Comité', representation_name: 'Águila', representation_type: 'País', allows_co_delegation: true },
    { source_line: 4, committee: 'Otro', representation_name: 'Aurora', representation_type: 'Persona', allows_co_delegation: false },
  ]);
});
test('rechaza encabezados, lotes vacíos, campos incompletos y booleanos ambiguos', () => {
  assert.throws(() => normalizeRows([['x']]), /invalid_headers/);
  assert.throws(() => normalizeRows([headers]), /empty_sheet/);
  assert.throws(() => normalizeRows([headers, ['c', 'n']]), /invalid_row/);
  assert.throws(() => normalizeRows([headers, ['c', 'n', 't', 'quizá']]), /invalid_boolean/);
});
test('obtiene por ID y escapa el título; usa dos lecturas', async () => {
  const calls = [];
  const responses = [
    { sheets: [{ properties: { sheetId: 0, title: "Catálogo de O'Brien" } }] },
    { values: [headers, ['C', 'R', 'País', 'SI']] },
  ];
  const metrics = { attempts: 0, rate_limited: 0 };
  const rows = await getSheetRows('sheet', 0, 'test', async () => true, metrics, {
    fetcher: async (url) => {
      calls.push(url);
      return Response.json(responses.shift());
    },
  });
  assert.equal(rows.length, 1);
  assert.equal(metrics.attempts, 2);
  assert.ok(decodeURIComponent(calls[1]).includes("'Catálogo de O''Brien'!A:D"));
});
test('429 respeta Retry-After, el presupuesto y el máximo de intentos', async () => {
  const metrics = { attempts: 0, rate_limited: 0 };
  const delays = [];
  await assert.rejects(readGoogle('https://example.test', 'test', async () => true, metrics, {
    fetcher: async () => new Response('', { status: 429, headers: { 'retry-after': '4' } }),
    wait: async (ms) => { delays.push(ms); },
  }), /google_unavailable/);
  assert.equal(metrics.attempts, 3);
  assert.equal(metrics.rate_limited, 3);
  assert.ok(delays.every((ms) => ms >= 4000));
  let fetched = false;
  await assert.rejects(readGoogle('https://example.test', 'test', async () => false, metrics, {
    fetcher: async () => { fetched = true; },
  }), /quota_budget/);
  assert.equal(fetched, false);
});
