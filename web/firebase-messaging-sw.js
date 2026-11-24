importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDqMZFODIhjPqAMUk0s7TWR4sS9I0hgSiQ',
  authDomain: 'dryclean-flutter-app.firebaseapp.com',
  projectId: 'dryclean-flutter-app',
  storageBucket: 'dryclean-flutter-app.firebasestorage.app',
  messagingSenderId: '778802274663',
  appId: '1:778802274663:web:cc923fe73992a9443b8fc2',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'DryClean Plus Driver';
  const options = {
    body: payload.notification?.body || 'You have a new route update.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});
