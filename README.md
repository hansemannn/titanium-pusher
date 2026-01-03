# Titanium Pusher

[![License](http://hans-knoechel.de/shields/shield-license.svg?v=2)](./LICENSE) [![Contact](http://hans-knoechel.de/shields/shield-twitter.svg?v=2)](http://twitter.com/hansemannnn)

## Summary

`ti.pusher` is a cross-platform Titanium module that wraps the native Pusher SDKs for iOS and Android. It exposes a small API to:

- [x] Initialize a Pusher client with an app key and optional auth configuration.
- [x] Connect and disconnect the socket.
- [x] Subscribe to a channel and bind events.
- [x] Trigger client events on a channel.

## Requirements

- Titanium SDK 13.0.0+
- iOS: PusherSwift (`PusherSwift.xcframework` included)
- Android: `com.pusher:pusher-java-client:2.4.4`

### Setup

#### Add to your Project

Place the module zip(s) in your project's `modules/iphone` and/or `modules/android` folder and register it in `tiapp.xml`:

```xml
<modules>
  <module platform="iphone">ti.pusher</module>
  <module platform="android">ti.pusher</module>
</modules>
```

#### Initialize Pusher

```js
import Pusher from 'ti.pusher';

Pusher.initialize({
  key: '<PUSHER_KEY>',
  options: {
    authEndpoint: 'https://your.api/pusher/auth', // optional
    accessToken: '<ACCESS_TOKEN>', // optional
    headers: { 'X-Custom-Header': 'value' } // optional
  }
});
```

Notes:

- The module uses TLS and is currently configured for the `eu` cluster.
- `options` are only required for authenticated (private) channels.
- The `Authorization` header is set from `accessToken` automatically.

### Build

If you want to build from source, make sure the Titanium SDK version in `ios/titanium.xcconfig` matches your environment and run:

- `ti build -p ios --build-only`
- `ti build -p android --build-only`

The resulting zips will be placed in `ios/dist` and `android/dist`.

## APIs

### Connect & Disconnect

```js
Pusher.connect();
Pusher.disconnect();
```

### Subscribe to a Channel

```js
const channel = Pusher.subscribe('private-updates');
```

- Android uses a *private* channel subscription under the hood.
- iOS uses a normal subscription.

### Bind to Events

```js
channel.addEventListener('data', (event) => {
  Ti.API.info(event.rawData);
});

channel.bind('new-message');
```

### Trigger Client Events

```js
channel.trigger('client-typing', {
  userId: 123,
  typing: true
});
```

### Unbind All Events

```js
channel.unbindAll();
```

Note: `unbindAll` is only implemented on iOS.

### Module Events

```js
Pusher.addEventListener('connectionchange', (event) => {
  Ti.API.info(`old=${event.old} new=${event.new}`);
});

Pusher.addEventListener('error', (event) => {
  Ti.API.error(event.error);
});
```

- iOS also fires `subscribe` with `{ name }` when a channel subscription succeeds.

## Example

See `example/app.js` for a minimal placeholder entry point you can expand.

## Author

Hans Knöchel

## License

See [LICENSE](LICENSE).

## Contributing

Pull requests are welcome! Please open an issue with repro steps or a clear description of the API you want to improve before submitting a PR.
