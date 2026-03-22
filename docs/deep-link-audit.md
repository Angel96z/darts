# Deep link pipeline audit (Lobby invite -> open app/web)

## Link generated in app
- File: `lib/features/darts_match/presentation/lobby/controllers/lobby_controller.dart`
- Method: `_buildInviteLink(String roomId)`
- Current format: `https://dartsroses.netlify.app/?roomId=<ROOM_ID>`

## Source of truth
- Global app state: `pendingRoomId` in `AppLinkState`.
- Deep link listeners only save `pendingRoomId`.
- No navigation and no join in link listeners.

## Link ingestion
- Web: `Uri.base.queryParameters['roomId']`.
- Mobile: `getInitialLink()` + `uriLinkStream`.

## Auth gate flow
- In `lib/app/app.dart`:
  - if user is not authenticated => `LoginScreen`
  - if authenticated and `pendingRoomId != null` => `RoomLobbyShellPageWrapper`
  - else => `HomeScreen`

## Link consumption and join
- `RoomLobbyShellPageWrapper` consumes `pendingRoomId` once.
- Then it calls `joinFromLink(roomId)` in `LobbyController`.

## Hosting + platform config
- Android app links: `android/app/src/main/AndroidManifest.xml` with host `dartsroses.netlify.app`.
- Web routing fallback: `netlify.toml` `/* -> /index.html`.
- iOS associated domain exists in `ios/Runner/Runner.entitlements`.
- iOS AASA still needs real `appID` (replace placeholder `TEAMID.com.tuo.package`).
