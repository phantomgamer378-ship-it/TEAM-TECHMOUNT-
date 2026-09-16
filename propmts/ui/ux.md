You are a senior product designer + Flutter UI engineer specializing in premium consumer security applications.

Redesign the complete VANIRAKSHAK Flutter application from the ground up.

IMPORTANT:
DO NOT simply change the existing colors, fonts, padding, or button styles.

The existing application should feel like an entirely new product experience with a stronger UX architecture, better information hierarchy, better navigation, better interaction design, and a premium visual identity.

Product:
VANIRAKSHAK

Tagline:
LISTEN • DETECT • VERIFY • PROTECT

Purpose:
VANIRAKSHAK protects users from AI-generated voice cloning, voice impersonation, scam calls, suspicious messages, and malicious links.

Core product capabilities:
- AI voice/deepfake detection
- Scam intent detection
- Speaker/identity verification
- Dynamic risk scoring
- Attack-type classification
- Adaptive liveness verification
- Hindi + Marathi + English/code-mixed support
- Suspicious message scanning
- Malicious URL checking
- Call history and investigation
- Explainable security decisions

==================================================
1. DESIGN INSPIRATION
==================================================

Use the attached UrCall UI reference as a VISUAL DESIGN REFERENCE.

Do NOT copy its brand, content, logo, exact layouts, or assets.

Instead, extract the following design principles from it:

- Large expressive typography
- Strong visual hierarchy
- Editorial/card-based composition
- Asymmetric layouts where appropriate
- Large rounded containers
- Deep green / forest surfaces
- Soft lime/green accent color
- Black/dark text on light cards
- White text on dark surfaces
- Subtle photographic/illustrative backgrounds
- Generous spacing
- Minimal borders
- Premium modern consumer-app feeling
- Large hero sections
- Strong use of negative space
- Rounded rectangular modules
- Visual storytelling instead of information overload

VANIRAKSHAK should feel like:

"Apple-level simplicity + premium fintech security + modern Indian safety product."

Avoid:

- Generic hacker/cyberpunk UI
- Excessive neon
- Excessive glowing borders
- Gaming aesthetics
- Too many gradients
- Dense SOC dashboards on mobile
- Tiny text everywhere
- Excessive cards inside cards
- Overuse of red
- Technical jargon shown to normal users

The application must feel trustworthy and calm first, technical second.

==================================================
2. VISUAL IDENTITY
==================================================

Primary visual direction:

Dark forest / near-black green foundation.

Suggested palette:

Background:
#06150F
#081C14

Surface:
#0D261C
#123126

Primary green:
#42D66F

Soft green:
#8DEFA5

Light background:
#F4F8F3

Text:
#FFFFFF
#DCE8DF
#0A120E

Risk states:

SAFE:
green

CAUTION:
amber/yellow

HIGH RISK:
orange/red

CRITICAL:
red

Use these risk colors only when communicating security state.

Do NOT make every screen red/green.

==================================================
3. TYPOGRAPHY
==================================================

Use a modern clean sans-serif font available in Flutter.

Typography hierarchy should be dramatic.

Example:

Hero title:
32–40px
Bold / ExtraBold

Section title:
24–28px

Card title:
17–20px

Body:
14–16px

Secondary:
12–14px

Risk number:
48–64px

Use large typography intentionally.

Avoid making everything 12–14px.

==================================================
4. UX PHILOSOPHY
==================================================

The app should answer one question immediately:

"Am I safe?"

The home screen should therefore prioritize:

1. Current protection status
2. Current call/security status
3. Recent threats
4. Quick actions
5. Security history

Users should not need to understand AI terminology.

Instead of:

"Audio spoof probability: 0.84"

show:

"Voice looks suspicious"

Then provide:

"Why?"

which opens technical evidence.

Technical detail should be progressively disclosed.

==================================================
5. APPLICATION NAVIGATION
==================================================

Use bottom navigation with 5 primary destinations:

HOME
CALLS
SCAN
REPORTS
MORE

Do NOT create 10+ bottom navigation items.

Inside the screens, use nested navigation where necessary.

Primary routes:

/
 /onboarding
 /home
 /live-call
 /call-result
 /calls
 /call-details
 /scan
 /message-scanner
 /url-checker
 /reports
 /profile
 /settings
 /assistant

Use Material 3 where useful, but heavily customize the components.

==================================================
6. ONBOARDING UX
==================================================

Create a premium 3-step onboarding experience.

Screen 1:
VANIRAKSHAK logo

Large statement:

"Your voice.
Your identity.
Protected."

Supporting text:

"Protection against AI voice cloning and impersonation scams."

Minimal illustration of a voice waveform inside a shield.

CTA:
"Get Protected"

Screen 2:

"Same voice.
Different intent."

Explain that scammers can imitate voices and manipulate conversations.

Visual:
two human silhouettes
connected by a waveform
with suspicious signal detection.

Screen 3:

"We listen for the warning signs."

Show four capabilities:

Detect
Understand
Verify
Protect

CTA:

"Start Protection"

Avoid long onboarding text.

==================================================
7. HOME SCREEN
==================================================

The home screen should be radically different from a traditional dashboard.

Start with a large greeting:

"You're protected."

or

"Good evening."

Then show a large protection-status card.

Example:

PROTECTION ACTIVE

"VANIRAKSHAK is watching for suspicious calls,
messages and links."

Shield icon.

Small status:
"All systems normal"

Then create a prominent CALL PROTECTION card:

"Call Protection"

Status:
ACTIVE

CTA:
"Manage"

Then create an editorial-style quick action composition.

For example:

[ Scan Message ]
[ Check Link ]

Then:

"Recent activity"

Use a clean chronological list.

Example:

Suspicious call
+91 XXXXX XXXXX
HIGH RISK
2 min ago

Message scanned
Bank verification request
SAFE

URL detected
Suspicious domain
HIGH RISK

The home screen should have breathing room.

==================================================
8. LIVE CALL EXPERIENCE
==================================================

THIS IS THE MOST IMPORTANT SCREEN.

The live-call screen should feel like a premium safety interface.

Do not create a generic phone dialer.

Top:

← Live Protection

"Analyzing call"

Then large caller identity:

Profile image/avatar

"Unknown Caller"

phone number

Use a subtle animated waveform.

Main visualization:

VOICE ACTIVITY

animated waveform responding to microphone/audio input.

Then show the security pipeline.

Instead of displaying technical jargon constantly, use human-readable stages:

Listening ✓
Understanding ✓
Checking voice ✓
Checking intent ✓
Calculating risk…

Then show:

CURRENT RISK

72 / 100

HIGH RISK

Use a circular or semi-circular risk visualization.

Under that show detected signals:

AI voice indicators
Urgent money request
Identity claim
Emotional manipulation

These should animate into the interface as they are detected.

==================================================
9. DYNAMIC RISK EXPERIENCE
==================================================

The risk score should feel alive.

Example sequence:

18
Low

30
Guarded

51
Suspicious

73
High Risk

86
Very High

93
Critical

Animate changes smoothly.

Never instantly jump without visual explanation.

Show:

"Risk increased because..."

Then:

+18 Identity claim
+15 Urgent money request
+12 Financial request
+9 Voice anomaly

The system should feel explainable.

==================================================
10. ADAPTIVE LIVENESS
==================================================

When risk becomes high:

Do NOT immediately show a huge technical error screen.

Instead show a calm intervention:

"Let's verify this caller."

Supporting copy:

"This call contains several suspicious signals.
Ask the caller to complete a quick verification."

CTA:

"Start Verification"

Then show a liveness challenge.

Examples:

"Ask them to say:
'VANIRAKSHAK 27'"

or

"Ask the caller to answer:
'What did we discuss yesterday?'"

Show progress:

Verification 1 of 2

After failure:

"Verification failed"

Risk updates:

93 / 100

CRITICAL

Then show:

"Do not share OTPs, PINs or financial information."

CTA:

"End Call"

Secondary:
"Report"

==================================================
11. CALL RESULT SCREEN
==================================================

After a suspicious call ends:

Create a premium incident-summary screen.

Large:

93
/100

CRITICAL RISK

Then:

"Likely impersonation scam"

Attack Type:
Family / Financial Impersonation

Language:
Hindi

Detected indicators:

AI voice indicators
Urgency
Money request
Identity claim
Verification failure

Then:

"Why was this flagged?"

Show expandable evidence sections.

CTA:

"Report This Call"

Secondary:
"View Details"

==================================================
12. CALL HISTORY
==================================================

Do not make call history look like a boring table.

Use timeline-style cards.

Each call:

Caller
Time
Duration
Risk state
Attack type

Example:

+91 98765 43210
10:42 AM
04:21

CRITICAL

Family impersonation

Use large visual risk indicators.

Add filters:

All
High Risk
Safe

==================================================
13. MESSAGE SCANNER
==================================================

Create a simple scanning experience.

Heading:

"Check a message."

Large input card.

Paste suspicious message.

CTA:

"Scan Message"

After analysis:

Risk Score

89 / 100

HIGH RISK

Then explain:

Fake bank warning
Urgency language
Suspicious link
Credential request

Use "Why?" expandable sections.

==================================================
14. URL CHECKER
==================================================

Create a highly visual URL checking experience.

Heading:

"Check before you tap."

URL input.

CTA:

"Check Link"

Result:

96 / 100

DANGEROUS

Then:

Domain
sbi-verification-example.com

Status:
Suspicious

Threat:
Phishing / Financial Scam

Detected indicators:

Lookalike domain
Credential harvesting
Suspicious redirect

CTA:

"Don't Open"

Secondary:
"Report Link"

==================================================
15. REPORTS
==================================================

Reports should feel like a personal security center.

Heading:

"Your security report"

Large statistics:

14
Calls analyzed

3
Threats detected

92%
Threat avoidance

Then a simple visual trend.

"Threat activity"

Show weekly/monthly trend.

Avoid overwhelming graphs.

==================================================
16. MORE / PROFILE
==================================================

Create a profile/security center.

Top:

Profile avatar

"Your Protection"

Protection status:
ACTIVE

Then settings grouped logically:

Protection

Call Protection
Message Scanner
Link Checker

Preferences

Language
Notifications

Privacy

Privacy & Security
Data Retention

Support

Help & Support
About VANIRAKSHAK

==================================================
17. PRIVACY UX
==================================================

Privacy should be visible and understandable.

Create a section:

"Your privacy matters."

Explain simply:

"Audio is processed only when needed."

"Raw recordings are not stored by default."

"Security evidence is retained for your control."

Add:

Privacy Mode
ON

Data Retention
Minimal

Use simple language.

==================================================
18. BHARAT VOICE SHIELD
==================================================

Regional language support must feel like a first-class feature.

Do not hide it deep in settings.

Support:

Hindi
Marathi
English

and:

Hindi + English
Marathi + English

code-mixed conversations.

During live analysis, show detected language:

Hindi

or:

Marathi + English

Transcript should support native scripts.

Example:

"मुझे अभी पैसे चाहिए..."

Do not force everything into English.

==================================================
19. VISUAL COMPONENT SYSTEM
==================================================

Create reusable Flutter components:

PremiumCard
SecurityCard
RiskGauge
RiskBadge
WaveformVisualizer
ProtectionStatus
ThreatTimeline
AnalysisStep
EvidenceCard
CallerHeader
ActionButton
PrimaryCTA
SecondaryCTA
BottomNavigation
SecurityBanner
ExpandableEvidence
LanguageBadge
ThreatIndicator
LivenessDialog

All components must be reusable.

==================================================
20. ANIMATIONS
==================================================

Animations should communicate state.

Use Flutter animation APIs.

Use:

Fade
Slide
Scale
Morph
Progress animation
Waveform movement
Risk number transitions
Card expansion
Bottom-sheet transitions

During live analysis:

waveform continuously moves.

When risk changes:

risk gauge animates.

When threat detected:

subtle vibration/visual feedback.

When critical:

use a restrained red pulse.

Do NOT use excessive glowing cyber animations.

==================================================
21. RESPONSIVE DESIGN
==================================================

Primary target:

Android phones.

Support:

small phones
normal phones
large phones
tablets

Respect:

SafeArea
system navigation
keyboard
different aspect ratios.

Use responsive sizing.

Do not hard-code layouts only for one device.

==================================================
22. ACCESSIBILITY
==================================================

Ensure:

strong contrast
large touch targets
readable typography
semantic labels
screen-reader-friendly controls

Never rely only on color to communicate risk.

Example:

HIGH RISK + icon + text

not just red.

==================================================
23. TECHNICAL FLUTTER ARCHITECTURE
==================================================

Use clean architecture suitable for a small hackathon team.

Suggested structure:

lib/

core/
  theme/
  constants/
  routes/
  utils/

features/

  onboarding/
  home/
  live_call/
  call_history/
  scanner/
  reports/
  profile/

shared/
  widgets/
  models/
  services/

Use:

Flutter
Dart
Material 3
GoRouter or equivalent routing
Riverpod/Provider for state management

Keep architecture simple enough for a beginner team.

Do not introduce unnecessary enterprise complexity.

==================================================
24. MOCK / DEMO MODE
==================================================

The application must work even before the real ML backend is connected.

Create a DemoMode.

The UI receives simulated events:

CALL_STARTED

AUDIO_RECEIVED

VOICE_ANALYSIS

TRANSCRIPT_UPDATE

SCAM_DETECTED

RISK_UPDATE

LIVENESS_REQUIRED

LIVENESS_FAILED

FINAL_DECISION

Example:

risk = 18
then 30
then 51
then 73
then 86
then 93

Clearly label simulated results when necessary.

DO NOT claim these values are actual model accuracy.

==================================================
25. BACKEND-READY DESIGN
==================================================

The Flutter UI must NOT be tightly coupled to mock data.

Create service abstractions.

Example:

AnalysisService

MockAnalysisService

ApiAnalysisService

WebSocketAnalysisService

This allows the team to replace mock data with FastAPI/WebSocket later.

Expected real-time events:

start_session
audio_chunk
stop_session

and backend events:

voice_analysis
asr_update
scam_analysis
risk_update
liveness_required
liveness_result
final_decision

==================================================
26. MICROPHONE / SIMULATED CALL
==================================================

For prototype:

Use phone/browser/device microphone when possible.

The user should press:

"Start Simulated Call"

Then the interface transitions into:

Incoming Call
→
Listening
→
Analyzing
→
Risk Detection
→
Verification
→
Final Result

The experience should feel like a REAL product demonstration.

==================================================
27. HOME SCREEN VISUAL COMPOSITION
==================================================

Take inspiration from the supplied UrCall reference.

Use a mixture of:

large cards
full-width sections
asymmetric compositions
large typography
dark green surfaces
light green feature cards
image/illustration panels
large rounded corners

For example:

--------------------------------
Good evening.

YOU'RE PROTECTED.
[ large shield visual ]

Protection Active
--------------------------------

[ Monitor Calls      ]

[ Scan Message ] [ Check Link ]

--------------------------------
Recent Threats
...
--------------------------------

This is preferable to:

Card
Card
Card
Card
Card
Graph
Card
Card

Create rhythm in the UI.

==================================================
28. DESIGN LANGUAGE
==================================================

VANIRAKSHAK should NOT look like:

"Kali Linux"
"cyber hacker"
"AI dashboard"
"crypto wallet"

It should look like:

"a premium consumer safety product."

The user should feel:

"I trust this application."

not:

"I'm looking at a developer dashboard."

==================================================
29. BRAND MOMENTS
==================================================

Use the name:

VANIRAKSHAK

Brand language:

"Your voice. Your identity. Protected."

"Bharat Voice Shield"

"Stay alert. Stay protected."

"Same voice. Different intent."

"Listen. Detect. Verify. Protect."

Use the tagline subtly rather than everywhere.

==================================================
30. DELIVERABLE
==================================================

First redesign the UX architecture.

Then redesign the UI.

Then implement the Flutter screens.

Do NOT modify only colors of the current app.

Actually rethink:

- information hierarchy
- navigation
- screen composition
- interactions
- animations
- risk communication
- live call experience
- security explanations
- onboarding
- empty states
- loading states
- error states
- success states

Every important screen must have:

Loading state
Empty state
Success state
Warning state
Error state

The final result should look like a production-quality Indian cybersecurity consumer application suitable for:

SIH judging
startup demonstrations
investor presentations
real user testing

Most importantly:

The LIVE CALL EXPERIENCE must be the hero experience.

A judge should be able to open the app, tap:

"Start Simulated Call"

and immediately understand:

A call is happening
↓
VANIRAKSHAK is listening
↓
The voice is being checked
↓
The conversation is being understood
↓
Risk is increasing
↓
Verification is triggered
↓
The user is protected.

Build the experience around this story.