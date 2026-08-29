# 💕 YUNJUNSIK SCHEDULER — Text-to-Action (TTA)

**"Write the way you always have. Let the app do the managing."**

Write your day as free-form prose — exactly as you would in a word processor — and the app reads the times out of your sentences, fires alarms on your phone *and* your PC, and files your side-notes into a memo board.

Flutter · Windows / Android / iOS · completed 2026-04-12 · [한국어 README →](README.ko.md)

---

## 1. Why this exists

I wrote my daily plan in a **word processor** every morning. Free-form, no fields, no "add event" dialogs — just a page of text. Writing it that way was fast and natural.

The problem came *after* writing. The document sat closed in a folder all day, and by 10:25 I had simply forgotten the 10:30 class existed. The plan was fine; my awareness of it during the day was not. **A plan that doesn't speak up is a plan that doesn't happen.**

Moving to a normal calendar app didn't stick, because typing into a structured calendar is a *different activity* from writing a plan — slower, and it breaks the train of thought. So the goal was deliberately narrow:

> **Change nothing about how the plan is written. Change everything about what happens after.**

You keep the writing habit on either device. The app takes over the remembering — and since people scribble notes while planning, it harvests those too.

---

## 2. What it does

- **You write prose.** One plain editor, same font and spacing as always. No forms.
- **It reads the clock out of your sentences.** `09시`, `9:30`, `10시 30분~13시`, `오후 3시`, `23시~01시`. A line with no time attaches to the task above it.
- **It understands "past midnight."** `23시 30분~01시 30분` schedules the end alarm for *tomorrow* 1:30 AM, without you starting a new date heading.
- **It rings on both devices.** Every start and end time becomes a real OS notification — system notification on mobile, toast on Windows.
- **It briefs you before the day starts.** 30 minutes before your first item, both devices get a **Daily Digest** with the whole day's plan and memos. This one alarm is the actual answer to the original problem.
- **It collects your scribbles.** Anything wrapped in triple backticks is extracted to a **Memo Board**, grouped by date.
- **One device writes, both ring.** Save on the laptop; the phone re-schedules its own alarms seconds later. Works offline too.
- **It stays out of the way on Windows.** Closing the window hides it to the system tray so alarms keep coming.

**Three screens:** Plan Editor (writing + live preview) · Memo Board · Alarm Center (today's alarms with on/off switches).

---

## 3. The pipeline

Everything is one flow: **text in → structure out → alarms + memos.**

```
✍️  Free-form text (phone or PC)
     │
     ├──────────────► ☁️  Cloud (one slot per date) ──live stream──► 🖥️  Other device ──┐
     │                                                                                  │
     ▼                                                                                  │
  Parser  ◄───────────────────────────────────────────────────────────────────────────┘
     │
     ├──► Live preview
     ├──► Memo Board
     └──► Alarm scheduler ──┬──► 📱 Mobile notification
                             └──► 🖥️  Windows toast
```

Three engine files do all the real work, independent of the UI:

| File | Role |
|---|---|
| [`schedule_parser.dart`](lib/engine/schedule_parser.dart) | Text → structured day plans. Pure, no dependencies. |
| [`notification_service.dart`](lib/engine/notification_service.dart) | Day plans → OS alarms on every platform. |
| [`firestore_service.dart`](lib/engine/firestore_service.dart) | Text ↔ cloud + offline cache. |

---

## 4. How each part is built

### 🕐 Time parser — `schedule_parser.dart`

One regex accepts every format a human actually types (AM/PM marker, hour, `시` or `:`, optional minutes, optional range marker), so no strict grammar is imposed on the user. → [`#L51`](lib/engine/schedule_parser.dart#L51)

The document is walked line by line and each line is sorted into one of three buckets → [`#L68`](lib/engine/schedule_parser.dart#L68):

- **Date line** (digit + 년/월/일) — closes the previous day section and opens a new one. → [`#L196`](lib/engine/schedule_parser.dart#L196)
- **Time line** — becomes a schedule block; the line is split on `~` to get start and end. → [`#L132`](lib/engine/schedule_parser.dart#L132)
- **Everything else** — appended to the block above it, so multi-line descriptions stay bound to the right time slot.

Normalization folds `24시` to `00시` and `오후 3시` to `15시`, and rejects anything outside 0–23 as a false positive. → [`#L168`](lib/engine/schedule_parser.dart#L168)

### 🌙 Overnight detection

If a block starts at 22:00 or later and ends before 06:00, it obviously crosses midnight. The end hour is shifted into a **24+ space** internally (01:00 → "25:00"), which keeps *start < end* true for all ordering logic downstream. → [`#L145`](lib/engine/schedule_parser.dart#L145)

When a real timestamp is needed, the 24 is subtracted back off and the calendar day is rolled forward by one. → [`#L273`](lib/engine/schedule_parser.dart#L273)

A document can hold several date sections, so the app also has to decide which day is "now." Rather than switching at midnight — useless if your day ends at 01:30 — it switches to the next section **30 minutes before that section's first item**, the same instant as the Daily Digest. The new day begins when you get briefed on it. → [`#L206`](lib/engine/schedule_parser.dart#L206)

### 📝 Memo recognition

Memos are marked with triple backticks — easy to type, impossible to hit by accident in a Korean schedule.

The whole document is split on that marker, and **the parity of the chunk index decides what it is**: even = schedule text, odd = memo. One pass, no state machine, no nesting bugs. Crucially the time scanner never even looks at odd chunks, so a memo saying "meet at 3" can't create a phantom alarm. Memos attach to whatever day section is open, so date grouping is free. → [`#L76`](lib/engine/schedule_parser.dart#L76)

Two consumers read that result: the **live preview**, which re-renders on every keystroke to show memos as yellow boxes and date lines in bold pink ([`tta_text_painter.dart`](lib/widgets/tta_text_painter.dart)), and the **Memo Board**, which keeps only the day sections that have memos ([`memo_board_screen.dart`](lib/screens/memo_board_screen.dart)).

### 🔔 Alarm scheduling structure

Scheduling is **fully declarative** — the app never patches an existing alarm set. Whenever the text changes it wipes everything and rebuilds, which makes "what alarms exist" a pure function of "what the text says." → [`#L239`](lib/engine/notification_service.dart#L239)

The rebuild goes: **cancel everything** → pick the active day section → resolve its real calendar date from the free-text heading → find the earliest start and schedule the **Daily Digest** 30 minutes before it → schedule one alarm per start time and one per end time, skipping anything already past.

Ids are handed out as a simple running sequence. The Alarm Center reproduces the *same* sequence with the same algorithm, so each switch on screen maps to the exact alarm it cancels. → [`alarm_center_screen.dart`](lib/screens/alarm_center_screen.dart)

The digest body is assembled from the whole plan plus a memo section, truncated to survive OS notification length limits. → [`#L399`](lib/engine/notification_service.dart#L399)

A rolling diagnostics report (requested / succeeded / failed / pending counts + recent logs) is published as observable state, because "the alarm didn't ring" is otherwise impossible to debug on someone else's phone. → [`#L14`](lib/engine/notification_service.dart#L14)

### ⏰ How alarms actually fire

Every alarm is registered **twice, through two independent layers**, because neither is reliable everywhere:

| Layer | Fires when |
|---|---|
| **OS scheduler** | App is backgrounded, closed, or the device is dozing |
| **In-process timer** | App is open — and it's the *only* path on Windows |

Scheduling is done in **zoned time**, not naive local time, so a timezone or DST change can't silently shift every alarm. → [`#L118`](lib/engine/notification_service.dart#L118)

**On mobile**, modern Android actively restricts exact alarms to save battery, so there's a **permission-aware fallback ladder**: exact-while-idle if permitted, otherwise inexact, with retries on failure — the app degrades instead of going silent. Notification and exact-alarm permissions are requested at init *and again after the first frame*, since cold-start dialogs often get swallowed. A boot receiver re-arms alarms after a reboot. → [`#L424`](lib/engine/notification_service.dart#L424) · [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)

**On Windows** there is no OS scheduler in play, so the timer layer is the alarm — which means the process has to stay alive. Hence the shell design: the ✕ button **hides** the window instead of quitting, and a tray icon provides *Open* / *Exit completely*. Only the tray's exit really terminates the app. → [`main.dart#L88`](lib/main.dart#L88)

### ☁️ Phone ↔ PC sync

One deliberate decision carries the whole design: **only the raw text is synced — alarms never are.**

Each device downloads the text and runs the parser locally to schedule *its own* alarms. No server-side scheduling, no push-token registry, no fan-out infrastructure — and it degrades gracefully, since an offline device simply keeps the alarms it last computed.

Storage is split into **one slot per date**, each holding the text and a last-saved timestamp. On save, the text is also mirrored to local storage — and the local write happens **even when the network write fails**, so a failed save is never a lost save; the UI reports it honestly instead of failing silently. On launch it tries the cloud first and falls back to the local cache, then immediately re-parses and re-arms. → [`firestore_service.dart`](lib/engine/firestore_service.dart)

The live loop is what makes two machines feel like one app: every device watches today's slot in real time. Edit on the laptop → the phone's listener fires → the phone re-parses → the phone wipes and re-schedules its own alarms, within seconds, with no action on the phone. Memo Board and Alarm Center subscribe to the same stream, so every screen on every device reads from one source of truth. → [`home_screen.dart#L69`](lib/screens/home_screen.dart#L69)

---

## 5. Code map

```
lib/
├── main.dart                       Entry point · navigation shell · Windows tray
├── engine/                         ◀── the brain (UI-independent)
│   ├── schedule_parser.dart        Time parsing · memo split · overnight logic
│   ├── notification_service.dart   Alarm scheduling · OS delivery · diagnostics
│   └── firestore_service.dart      Cloud sync · offline cache
├── screens/                        Plan Editor · Memo Board · Alarm Center
├── widgets/                        Live text painter · memo card · buttons
└── theme/                          Colors · global theme
```

| Mechanism | Source |
|---|---|
| Time regex | [`schedule_parser.dart#L51`](lib/engine/schedule_parser.dart#L51) |
| Main parse loop | [`schedule_parser.dart#L68`](lib/engine/schedule_parser.dart#L68) |
| Overnight detection | [`schedule_parser.dart#L145`](lib/engine/schedule_parser.dart#L145) |
| Overnight → timestamp | [`schedule_parser.dart#L273`](lib/engine/schedule_parser.dart#L273) |
| Active-day selection | [`schedule_parser.dart#L206`](lib/engine/schedule_parser.dart#L206) |
| Memo split | [`schedule_parser.dart#L76`](lib/engine/schedule_parser.dart#L76) |
| Memo rendering | [`tta_text_painter.dart`](lib/widgets/tta_text_painter.dart) |
| Scheduling pipeline | [`notification_service.dart#L239`](lib/engine/notification_service.dart#L239) |
| Daily Digest body | [`notification_service.dart#L399`](lib/engine/notification_service.dart#L399) |
| Dual-layer firing | [`notification_service.dart#L424`](lib/engine/notification_service.dart#L424) |
| Permissions · boot receiver | [`AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml) |
| Windows tray · prevent-close | [`main.dart#L88`](lib/main.dart#L88) |
| Cloud read/write/stream | [`firestore_service.dart`](lib/engine/firestore_service.dart) |
| Cross-device re-arm | [`home_screen.dart#L69`](lib/screens/home_screen.dart#L69) |

**Stack:** Flutter · Firebase Core + Cloud Firestore · `shared_preferences` · `flutter_local_notifications` + `timezone` · `local_notifier` · `window_manager` + `tray_manager`

---

## 6. Running it

```bash
flutter pub get
flutter run -d windows        # or: flutter run -d <device-id>
```

To point it at your own Firebase project, run `flutterfire configure` to regenerate `lib/firebase_options.dart`.

**Windows:** toast notifications need a Start-menu shortcut (created automatically on first launch); keep `app_icon.ico` next to the built `.exe`.
**Android:** grant both the notification permission and "Alarms & reminders" on first launch — without exact-alarm permission the app still works, but alarms may drift under Doze.

### Writing syntax

| You type | The app does |
|---|---|
| `2026년 4월 9일 계획` | Starts a new day section · bold pink + 💕 |
| `09시 기상` | Alarm at 09:00 |
| `10시 30분~13시 형이상학 수업` | Alarms at 10:30 and 13:00 |
| `오후 3시 회의` | Alarm at 15:00 |
| `23시 30분~01시 30분 휴식` | 23:30 today, 01:30 **tomorrow** |
| a line with no time | Attaches to the task above it |
| triple backticks | Yellow memo box · archived to Memo Board |
| *(automatic)* | Daily Digest 30 min before your first item |
