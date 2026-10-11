// 9ja Transport PWA worker: app shell offline-first (PRD §9 spirit),
// CDN libs cached best-effort, map tiles left to network (too big to cache).
const SHELL = [
  '/web-app-preview.html',
  '/manifest.webmanifest',
  '/icons/icon-192.png',
  '/icons/icon-512.png',
  '/landing-page.html',
];
const SHELL_CACHE = 'nineja-shell-v1';
const LIB_CACHE = 'nineja-lib-v1';

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(SHELL_CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== SHELL_CACHE && k !== LIB_CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET') return;
  if (u.origin === self.location.origin) {
    e.respondWith(
      caches.match(e.request).then((hit) => hit || fetch(e.request).then((r) => {
        const copy = r.clone();
        caches.open(SHELL_CACHE).then((c) => c.put(e.request, copy));
        return r;
      }).catch(() => caches.match('/web-app-preview.html')))
    );
  } else if (u.host === 'cdnjs.cloudflare.com') {
    e.respondWith(
      caches.open(LIB_CACHE).then((c) => c.match(e.request).then((hit) =>
        hit || fetch(e.request).then((r) => { c.put(e.request, r.clone()); return r; })
          .catch(() => new Response('', {status: 503, statusText: 'offline'}))))
    );
  }
  // map tiles + everything else: network only (fresh positions, no stale maps)
});
