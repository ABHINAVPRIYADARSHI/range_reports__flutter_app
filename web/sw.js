// ------------------------------
// LISTEN FOR PUSH EVENTS
// ------------------------------
self.addEventListener('push', function(event) {
  console.log('[Service Worker] Push Received:', event);

  // Default payload structure (in case event.data is missing)
  let payload = {
    title: 'Daily report reminder',
    body: 'Please log in and submit your report.',
    url: '/',  // default redirect
  };

  try {
    if (event.data) {
      // Expecting JSON payload from Edge Function
      const data = event.data.json();
      payload.title = data.title || payload.title;
      payload.body  = data.body  || payload.body;
      payload.url   = data.url   || payload.url;
    }
  } catch (e) {
    console.error('[Service Worker] Error parsing push payload:', e);
    // fallback to text
    payload.body = event.data?.text() || payload.body;
  }

  const options = {
    body: payload.body,
    icon: '/icons/Icon-192x192.png',
    badge: '/icons/Icon-192x192.png',
    vibrate: [100, 50, 100],
    data: {
      url: payload.url,       // store redirect url (important)
      dateOfArrival: Date.now(),
    },
  };

  event.waitUntil(
    self.registration.showNotification(payload.title, options)
  );
});


// ------------------------------
// HANDLE NOTIFICATION CLICK
// ------------------------------
self.addEventListener('notificationclick', function(event) {
  console.log('[Service Worker] Notification click:', event);

  event.notification.close();

  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then(clientList => {
        // If page is already open, focus it
        for (const client of clientList) {
          if (client.url.includes(urlToOpen) && 'focus' in client) {
            return client.focus();
          }
        }
        // Else open a new window
        return clients.openWindow(urlToOpen);
      })
  );
});
