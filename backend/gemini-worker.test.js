import assert from 'node:assert/strict';
import test from 'node:test';

import worker, { __test } from './gemini-worker.js';

test('health reports whether the Gemini secret is configured', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/health'),
    { GEMINI_API_KEY: 'configured' },
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    ok: true,
    service: 'blackshell-golf-ai',
    configured: true,
  });
  assert.match(response.headers.get('x-request-id'), /^[0-9a-f-]{36}$/);
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('denies browser origins unless they are explicitly allowed', async () => {
  const denied = await worker.fetch(
    new Request('https://example.test/health', {
      headers: { Origin: 'https://untrusted.example' },
    }),
    { GEMINI_API_KEY: 'configured' },
  );
  assert.equal(denied.status, 403);
  assert.equal(denied.headers.get('access-control-allow-origin'), null);

  const allowed = await worker.fetch(
    new Request('https://example.test/analyze-swing', {
      method: 'OPTIONS',
      headers: { Origin: 'https://app.example' },
    }),
    { APP_ORIGIN: 'https://app.example, https://admin.example' },
  );
  assert.equal(allowed.status, 204);
  assert.equal(
    allowed.headers.get('access-control-allow-origin'),
    'https://app.example',
  );
  assert.equal(allowed.headers.get('vary'), 'Origin');
});

test('requires the optional bearer token when configured', async () => {
  const response = await worker.fetch(
    new Request('https://example.test/analyze-swing', { method: 'POST' }),
    { GEMINI_API_KEY: 'key', APP_BEARER_TOKEN: 'expected' },
  );
  assert.equal(response.status, 401);
  assert.equal(
    response.headers.get('www-authenticate'),
    'Bearer realm="blackshell-golf-ai"',
  );
  assert.equal((await response.json()).code, 'unauthorized');
});

test('returns 429 before parsing a video when the edge limit is exhausted', async () => {
  let rateLimitKey;
  const response = await worker.fetch(
    new Request('https://example.test/analyze-swing', {
      method: 'POST',
      headers: {
        'CF-Connecting-IP': '203.0.113.42',
        'X-BlackShell-Client': 'flutter',
      },
    }),
    {
      GEMINI_API_KEY: 'key',
      AI_RATE_LIMITER: {
        limit: async ({ key }) => {
          rateLimitKey = key;
          return { success: false };
        },
      },
    },
  );
  assert.equal(response.status, 429);
  assert.equal(rateLimitKey, 'flutter:203.0.113.42:/analyze-swing');
  assert.equal(response.headers.get('retry-after'), '60');
  assert.deepEqual(await response.json(), {
    code: 'rate_limited',
    error: 'Too many swing analyses. Please try again in a minute.',
    retryable: true,
  });
});

test('forwards video at the configured frame rate and returns validated JSON', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  let upstreamRequest;
  globalThis.fetch = async (url, options) => {
    upstreamRequest = { url, options };
    return new Response(
      JSON.stringify({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    summary: 'Balanced motion.',
                    strengths: ['Stable setup'],
                    improvements: ['Quieter transition'],
                    recommendations: ['Pause drill'],
                    observations: [
                      {
                        phase: 'Top',
                        observation: 'Good width.',
                        timestamp: '00:02',
                      },
                    ],
                    safetyNotes: [],
                  }),
                },
              ],
            },
          },
        ],
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  };

  const form = new FormData();
  form.set('context', JSON.stringify({ languageCode: 'en', club: '7 iron' }));
  form.set('video', new Blob(['short-video'], { type: 'video/mp4' }), 'swing.mp4');
  const response = await worker.fetch(
    new Request('https://example.test/analyze-swing', {
      method: 'POST',
      body: form,
    }),
    { GEMINI_API_KEY: 'secret', VIDEO_FPS: '12' },
  );

  assert.equal(response.status, 200);
  assert.equal((await response.json()).analysis.summary, 'Balanced motion.');
  assert.match(upstreamRequest.url, /gemini-3\.5-flash:generateContent/);
  const payload = JSON.parse(upstreamRequest.options.body);
  assert.equal(payload.contents[0].parts[0].videoMetadata.fps, 12);
  assert.equal(payload.contents[0].parts[0].inlineData.mimeType, 'video/mp4');
  assert.equal(payload.generationConfig.thinkingConfig, undefined);
  assert.equal(payload.generationConfig.responseFormat, undefined);
  assert.equal(payload.generationConfig.responseMimeType, 'application/json');
  assert.match(payload.contents[0].parts[1].text, /Required keys are summary/);
});

test('falls back when the primary Gemini model is unavailable', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => {
    globalThis.fetch = originalFetch;
  });

  const requestedModels = [];
  globalThis.fetch = async (url) => {
    requestedModels.push(url);
    if (requestedModels.length === 1) {
      return new Response(
        JSON.stringify({ error: { message: 'Model not found.' } }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      );
    }
    return new Response(
      JSON.stringify({
        candidates: [
          {
            content: {
              parts: [
                {
                  text: JSON.stringify({
                    summary: 'Fallback succeeded.',
                    strengths: [],
                    improvements: [],
                    recommendations: [],
                    observations: [],
                    safetyNotes: [],
                  }),
                },
              ],
            },
          },
        ],
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  };

  const form = new FormData();
  form.set('video', new Blob(['video'], { type: 'video/mp4' }), 'swing.mp4');
  const response = await worker.fetch(
    new Request('https://example.test/analyze-swing', {
      method: 'POST',
      body: form,
    }),
    {
      GEMINI_API_KEY: 'secret',
      GEMINI_MODEL: 'gemini-primary',
      GEMINI_FALLBACK_MODELS: 'gemini-fallback',
    },
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.modelUsed, 'gemini-fallback');
  assert.match(requestedModels[0], /gemini-primary/);
  assert.match(requestedModels[1], /gemini-fallback/);
});

test('normalizes common camera video MIME aliases', () => {
  assert.equal(__test.normalizeMimeType('video/x-m4v'), 'video/mp4');
  assert.equal(__test.normalizeMimeType('video/3gp'), 'video/3gpp');
});

test('validates and bounds structured Gemini output', () => {
  const normalized = __test.normalizeAnalysis({
    summary: `  ${'a'.repeat(1700)}  `,
    strengths: [' Stable posture '],
    improvements: [],
    recommendations: [],
    observations: [
      { phase: ' Top ', observation: ' Good width. ', timestamp: ' 00:02 ' },
    ],
    safetyNotes: [],
  });
  assert.equal(normalized.summary.length, 1600);
  assert.equal(normalized.strengths[0], 'Stable posture');
  assert.deepEqual(normalized.observations[0], {
    phase: 'Top',
    observation: 'Good width.',
    timestamp: '00:02',
  });
  assert.throws(
    () =>
      __test.normalizeAnalysis({
        summary: 'Summary',
        strengths: [],
        improvements: ['1', '2', '3', '4'],
        recommendations: [],
        observations: [],
        safetyNotes: [],
      }),
    /Invalid improvements/,
  );
});
