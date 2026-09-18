/* ============================================================================
   Overload — service worker
   ----------------------------------------------------------------------------
   Purpose: make the app shell work with no connection, so you can open it and
   log a workout in a gym basement. Data sync is not this file's job — the app's
   own persistence layer handles that (localStorage first, Supabase after).

   Deliberately narrow: this only ever touches same-origin GET requests. Every
   cross-origin request — Supabase API calls, Google Fonts — passes straight
   through untouched. Caching Supabase responses would serve people stale
   workout data, which is far worse than a slow load.

   Bump CACHE_VERSION whenever the shell files change, or browsers will keep
   serving the old app.
============================================================================ */

const CACHE_VERSION = 'overload-v1';

const SHELL = [
  './',
  './index.html',
  './supabase-config.js',
  './vendor/supabase.js',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
  './icon-maskable-512.png',
  './apple-touch-icon.png',
  './favicon-32.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE_VERSION);
    // addAll fails the whole install if any single file 404s, which would leave
    // the app with no offline support at all. Add them individually instead.
    await Promise.all(SHELL.map(async (url) => {
      try { await cache.add(new Request(url, { cache: 'reload' })); }
      catch (e) { console.warn('[sw] could not precache', url, e); }
    }));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.map(n => n === CACHE_VERSION ? null : caches.delete(n)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;  // Supabase, fonts, etc.

  // Navigations: network first so a deployed update is picked up promptly,
  // falling back to the cached shell when offline.
  if (req.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        const fresh = await fetch(req);
        const cache = await caches.open(CACHE_VERSION);
        cache.put('./index.html', fresh.clone());
        return fresh;
      } catch (e) {
        const cached = await caches.match('./index.html');
        return cached || new Response(
          '<h1>Offline</h1><p>Overload needs to load once while online before it can work offline.</p>',
          { status: 503, headers: { 'Content-Type': 'text/html' } }
        );
      }
    })());
    return;
  }

  // The Supabase config must never be served stale: if the keys are corrected
  // or rotated, a cache-first copy would keep pointing the app at the old
  // project indefinitely (until CACHE_VERSION happened to be bumped). Network
  // first, with the cached copy only as an offline fallback.
  if (url.pathname.endsWith('/supabase-config.js')) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE_VERSION);
      try {
        const fresh = await fetch(req, { cache: 'no-store' });
        if (fresh && fresh.ok) cache.put(req, fresh.clone());
        return fresh;
      } catch (e) {
        const cached = await cache.match(req);
        return cached || new Response('window.OVERLOAD_CONFIG=window.OVERLOAD_CONFIG||{};',
          { headers: { 'Content-Type': 'application/javascript' } });
      }
    })());
    return;
  }

  // Static assets: serve from cache immediately, refresh in the background.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE_VERSION);
    const cached = await cache.match(req);

    const update = fetch(req).then((res) => {
      if (res && res.ok) cache.put(req, res.clone());
      return res;
    }).catch(() => null);

    return cached || (await update) || new Response('', { status: 504 });
  })());
});
