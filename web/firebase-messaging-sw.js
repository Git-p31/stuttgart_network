importScripts('https://www.gstatic.com/firebasejs/11.0.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAjFDeVoyWujua_AFz-20TzKEFskDWuvtc",
  authDomain: "kjmc-132af.firebaseapp.com",
  projectId: "kjmc-132af",
  messagingSenderId: "985778294896",
  appId: "1:985778294896:web:ce37e77c270c28ca2b24b5"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png'
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});