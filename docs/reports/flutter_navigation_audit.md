# Flutter Navigation Audit

## CURRENT ROUTES
- `/` (Splash/Router entry)
- `/onboarding`
- `/home`
- `/calls`
- `/calls/live/:sessionId`
- `/scan`
- `/scan/message`
- `/scan/url`
- `/reports`
- `/more/profile`

## CURRENT NAVIGATION
- State Management: Riverpod
- Routing Library: `go_router`
- Bottom Navigation Shell: implemented via `StatefulShellRoute` in `app.dart`
- Deep linking setup: Basic route paths match schema.

## CURRENT PROBLEMS
- Old prototype files (`history_screen.dart`, `scanner_screen.dart`, etc.) were cluttering the root `lib/` directory causing 95+ analyzer errors and confusing the architecture.
- The `api_client.dart` had a hard-coded fallback to localhost or 10.0.2.2 which violates the "No hardcoded URLs in production" rule.
- Some imports were pointing to non-existent `vcs_theme.dart` instead of `vr_theme.dart`.

## ROUTES TO KEEP
All routes inside the `lib/features/` architecture:
- `home_screen.dart`
- `call_history_screen.dart`
- `live_call_screen.dart`
- `scanner_screen.dart`
- `profile_screen.dart`

## ROUTES TO REMOVE (Completed)
- `lib/home_screen.dart`
- `lib/history_screen.dart`
- `lib/scanner_screen.dart`
- `lib/call_analysis_screen.dart`
- `lib/widgets.dart`

## ROUTES TO CREATE
- Nested Liveness modal/route (`/calls/live/:sessionId/liveness`).
- Additional `/more/` sub-routes (Settings, Trusted Contacts, Privacy) for future phases.

## STATE RISKS
- Handled: The `LiveCallNotifier` owns the WebSocket state, preventing the route from directly owning business logic.

## UX RISKS
- Fixed: Production URL centrally managed via `AppConfig`.
- Fixed: Removing duplicate prototype files avoids double-renders and route collision.
