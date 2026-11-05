// Den Duel's service worker (tools/build_web.sh puts it in place of
// Godot's own). Godot's served every file from its cache first, so an
// iPhone home-screen app kept running an old build until it had been closed
// and reopened, sometimes twice. This one always asks the network first
// (cheaply: the server answers "not changed" when nothing is new) and only
// falls back to the cached copy when there's no connection. A new version
// takes over at once and drops the old caches.
const CACHE = 'den-duel-___BUILD___';

self.addEventListener('install', () => {
	self.skipWaiting();
});

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		await Promise.all(keys.filter((key) => key !== CACHE).map((key) => caches.delete(key)));
		await self.clients.claim();
	})());
});

self.addEventListener('fetch', (event) => {
	const request = event.request;
	if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) {
		return;
	}
	event.respondWith((async () => {
		const cache = await caches.open(CACHE);
		try {
			const response = await fetch(request, { cache: 'no-cache' });
			if (response.ok) {
				cache.put(request, response.clone());
			}
			return response;
		} catch (err) {
			const cached = await cache.match(request);
			if (cached) {
				return cached;
			}
			throw err;
		}
	})());
});

self.addEventListener('message', (event) => {
	if (event.data === 'update' || event.data === 'claim') {
		self.skipWaiting();
	}
});
