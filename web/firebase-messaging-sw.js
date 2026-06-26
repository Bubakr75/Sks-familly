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
  };
  self.registration.showNotification(title, options);
});
