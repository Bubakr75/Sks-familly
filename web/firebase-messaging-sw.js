importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyABGqJErNqh4xr2jIyf4PHQzxX4jYHgQ0I',
  appId: '1:1033903328737:web:5e7ac00165d5edf8b2d6a0',
  messagingSenderId: '1033903328737',
  projectId: 'sks-familly-3f205',
  storageBucket: 'sks-familly-3f205.firebasestorage.app',
  authDomain: 'sks-familly-3f205.firebaseapp.com',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  const title = (payload.notification && payload.notification.title) || 'SKS Family';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'sks-family-' + Date.now(),
    data: payload.data || {},
    vibrate: [200, 100, 200],
  };
  return self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  // URL cible : data.url (Cloud Functions) si présent, sinon racine
  const targetUrl = (event.notification.data && event.notification.data.url)
                  || (event.notification.data && event.notification.data.link)
                  || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Focus une fenêtre déjà ouverte sur l'app si possible
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          if ('navigate' in client) { client.navigate(targetUrl).catch(() => {}); }
          return client.focus();
        }
      }
      if (clients.openWindow) { return clients.openWindow(targetUrl); }
    })
  );
});

self.addEventListener('push', (event) => {
  if (!event.data) return;
  let payload;
  try { payload = event.data.json(); } catch (e) {
    payload = { notification: { title: 'SKS Family', body: event.data.text() } };
  }
  const title = (payload.notification && payload.notification.title) || 'SKS Family';
  const options = {
    body: (payload.notification && payload.notification.body) || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});
self.addEventListener('install', () => { self.skipWaiting(); });
