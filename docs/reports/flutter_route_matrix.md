# Route State Matrix

| Route | Authentication | Data Source | Loading | Success | Empty | Error | Back Behavior | Deep-Link Behavior |
|-------|----------------|-------------|---------|---------|-------|-------|---------------|--------------------|
| `/` (Splash) | N/A | Local Storage | Shimmer/Logo | Redirects to Onboarding or Home | N/A | N/A | Exits App | Handled |
| `/onboarding` | N/A | N/A | N/A | N/A | N/A | N/A | Exits App | N/A |
| `/home` | Protected | `ApiClient` | Skeletons | Dashboards | N/A | "Connection Lost" | System Back / Minimize | Supported |
| `/calls` | Protected | `CallRepository` | Skeletons | List of Calls | "No Recent Calls" | Retry Button | Returns to Home tab | Supported |
| `/calls/live/:sessionId` | Protected | `WebSocketService` | "Connecting..." | Live Waveform / Transcripts | N/A | Safe fallback | Confirmation Modal | Handled via guarded deep link |
| `/scan` | Protected | `ScannerRepository` | Skeletons | Categories | N/A | N/A | Returns to Home tab | Supported |
| `/scan/message` | Protected | `ApiClient` | "Analyzing..." | Risk Result | N/A | Retry Button | Returns to `/scan` | Supported |
| `/scan/url` | Protected | `ApiClient` | "Checking Link..." | Risk Result | N/A | Retry Button | Returns to `/scan` | Supported |
| `/reports` | Protected | `ReportRepository` | Charts loading | Stats UI | N/A | Retry Button | Returns to Home tab | Supported |
| `/more/profile` | Protected | `UserRepository` | Loading Profile | Profile UI | N/A | Retry Button | Returns to Home tab | Supported |
