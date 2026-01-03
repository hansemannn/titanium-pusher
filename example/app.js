import Pusher from 'ti.pusher';

Pusher.initialize({
  key: '<PUSHER_KEY>',
  options: {
    authEndpoint: 'https://your.api/pusher/auth', // optional
    accessToken: '<ACCESS_TOKEN>', // optional
    headers: { 'X-Custom-Header': 'value' } // optional
  }
});

Pusher.addEventListener('connectionchange', (event) => {
  Ti.API.info(`old=${event.old} new=${event.new}`);
});

Pusher.addEventListener('error', (event) => {
  Ti.API.error(event.error);
});

Pusher.connect();

const channel = Pusher.subscribe('private-updates');

channel.addEventListener('data', (event) => {
  Ti.API.info(event.rawData);
});

channel.bind('new-message');

channel.trigger('client-typing', {
  userId: 123,
  typing: true
});
