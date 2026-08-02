# TrustTunnel mobile client

Flutter mobile client for the self-hosted TrustTunnel service.

Repositories:

- Server: <https://github.com/moreprivate/tt-server>
- Console client: <https://github.com/moreprivate/tt-client>
- This app: <https://github.com/moreprivate/tt-mobile>

## Current scope

Android is the supported development target. The Android app builds the
native client from the separately maintained `moreprivate/tt-client` checkout
at build time. The mobile repository does not vendor or publish a second copy
of the client source.

The app currently provides server management, routing profiles, and VPN
connect/disconnect/reconnect. TOML import is not implemented; server values
must be entered in the app.

Apple targets still use the existing prebuilt framework package and therefore
remain separate work.

## Prerequisites

- Flutter stable (3.44 or newer)
- Dart SDK supplied by Flutter
- Android SDK with API 36
- Android NDK `29.0.14206865`
- CMake `3.31.6`
- The versioned `tt-client` Android Maven artifact selected by the build

## Android development

```bash
git clone https://github.com/moreprivate/tt-mobile.git
cd tt-mobile

flutter pub get
make gen
make ln
flutter run -d <android-device>
```

The build consumes a versioned `tt-client` Android Maven repository under
`third_party/tt-client-maven`. CI downloads and verifies that archive from the
`moreprivate/tt-client` release selected by `client_release`; no upstream
GitHub Maven repository or token is used.

### Release APK (local or CI) — signed, replaceable

Release builds **require** a fixed signing keystore so every APK (laptop Docker
chain, GitHub cloud, self-hosted runner) can **replace** the previous install.

**One-time local keystore in HOME** (not in the repo; survives deleting the clone):

```bash
cd tt-mobile
make aux-setup-android-signing
# → $HOME/.config/tt-mobile/trusttunnel.keystore
# → android/local.properties (absolute path + passwords; gitignored)
# Back up ~/.config/tt-mobile/ and the password offline.
```

**Same key into GitHub** (repo or org secrets for cloud + self-hosted):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 ~/.config/tt-mobile/trusttunnel.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_ALIAS` | `trusttunnel` (default from setup) |
| `ANDROID_KEY_PASSWORD` | key password |

Prefer **release + split per ABI**:

```bash
# after third_party/tt-client-maven is populated and ttClientVersion is set
make release-apk
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

From the sibling chain (`tt-manage`):

```bash
make clean && make build
# → ../.tt-build/tt-mobile-arm64-v8a-release.apk  (signed)
```

Without signing config, the release Gradle task **fails** (no silent unsigned/debug-signed APKs).

**Why old APKs were ~200MB:** debug mode (large `libflutter`, Vulkan validation
layer, uncompressed Dart assets) × three ABIs in one fat APK. Release arm64 is
roughly **10× smaller**.

Optional fat single APK (all ABIs, ~90MB): `make release-apk-fat`.

For an emulator:

```bash
emulator -avd <avd-name> &
adb wait-for-device
flutter devices
flutter run -d emulator-5554
# or install the x86_64 split: adb install app-x86_64-release.apk
```

## Configure a server

Create a client configuration on the server, then enter these values through
**Servers → Create**:

- display name
- endpoint address and port
- endpoint hostname/SNI
- username and password
- DNS servers
- transport protocol (`http2` → HTTP/2, `http3` → QUIC)
- certificate or system certificate verification

The server exports the required values. Keep certificate verification enabled;
do not use an insecure skip-verification setting for normal operation.

## Verify a connection

Tap **Connect**, approve the Android VPN permission, and verify the app reports
`connected`. Test **Disconnect** and **Reconnect** as well.

On the server, observe the endpoint session:

```bash
ss -tn state established '( sport = :443 )'
```

## Selecting the native client

CI uses the newest `moreprivate/tt-client` release by default. A manual build
can select an exact client release tag with the `client_release` workflow input.
