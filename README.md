# MorePrivate tt-mobile

[tt-mobile](https://github.com/moreprivate/tt-mobile) is the Flutter Android application for a self-hosted
[tt-server](https://github.com/moreprivate/tt-server). It uses the native
Android client library built by
[tt-client](https://github.com/moreprivate/tt-client).

Repositories:

- Server: <https://github.com/moreprivate/tt-server>
- Native/console client: <https://github.com/moreprivate/tt-client>
- This application: <https://github.com/moreprivate/tt-mobile>

## Current functionality

The Android app can create and edit server profiles, import a server TOML,
manage routing profiles, and connect, disconnect, or reconnect the Android VPN.
Routing profiles are app settings and are not written into server TOML. The
Android application ID is `com.moreprivate.tt_mobile`.

## Android development

The reproducible build uses Flutter 3.44.8, Android API 36, NDK
29.0.14206865, CMake 3.31.6, and Java 21:

```sh
git clone https://github.com/moreprivate/tt-mobile.git
cd tt-mobile
flutter pub get
make gen
make ln
flutter run -d <android-device>
```

The app consumes a versioned Android Maven archive from a `tt-client`
release. CI downloads and verifies that archive using the exact
`client_release` input; it does not depend on a checkout outside this
repository or an upstream GitHub Maven repository.

## Release APKs

The supported installable output is a signed release APK split by ABI:

```sh
make aux-setup-android-signing
make release-apk
```

The keystore is stored at
`$HOME/.config/moreprivate/tt-mobile/tt-mobile.keystore` and is never committed. CI
uses the same key through `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and
`ANDROID_KEY_PASSWORD`; without signing configuration it refuses to publish
installable APKs.

Use `app-arm64-v8a-release.apk` for modern phones.
`make release-apk-fat` is available for a larger all-ABI APK. Debug APKs are
for development only and use a different key, so they cannot replace a
release APK on a device.

The reproducible workflow is
`.github/workflows/build-mobile-targets.yml`. It downloads the exact client
release, builds arm64-v8a, armeabi-v7a, and x86_64 APKs, and publishes
checksums through the `tt-manage` release chain.

## Import a server profile

On the server:

```sh
bash tt-server.sh add-user phone
```

Copy the resulting `phone.toml` to the phone and choose **Import config** in
the app. Manual profile creation remains available.

## Verify a connection

Tap **Connect**, approve Android VPN permission, and confirm the app reports
`connected`. Exercise **Disconnect** and **Reconnect** as well. On the VPS:

```sh
ss -tn state established '( sport = :443 )'
```

## Related local build

To build server, native client, and mobile with the same pinned toolchain used
by CI:

```sh
cd ../tt-manage
make check
make build
```

## License

Apache 2.0. See [LICENSE](LICENSE).
