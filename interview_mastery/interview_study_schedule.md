# Senior Flutter Developer — Hour-by-Hour Master Study Schedule
**Target**: Friday 10:00 AM Interview | **Timezone**: UAE (GST)  
**Timeline**: Wednesday, Sept 16 – Friday, Sept 18

---

## The 3-Day Blueprint Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                        3-DAY STUDY MASTER PLAN                         │
├───────────────────┬────────────────────────────────────────────────────┤
│ Wednesday (Day 1) │ Projects, Behavioral STAR Stories & Portal Coding  │
│ Thursday  (Day 2) │ Flutter Engine, System Design & Logic Algorithms   │
│ Friday    (Day 3) │ Final Polish, Tech Setup & Game Day Execution      │
└───────────────────┴────────────────────────────────────────────────────┘
```

---

## DAY 1: Wednesday, September 16 (Project Depth & Portal Form Factors)

### 🌅 Morning Session (09:00 AM – 01:00 PM): Project Stories & Identity
- **Goal**: Lock down your 90-second introduction and project narratives until they feel natural.
- **Documents to Study**:
  - [senior_flutter_interview_master_guide.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/senior_flutter_interview_master_guide.md) (Sections 1 & 2).
  - [flutter_interview_qa_and_coding_master.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/flutter_interview_qa_and_coding_master.md) (Part I: Project Q&A).
- **Action Items**:
  - [ ] **09:00 – 10:30**: Read the **90-Second Intro** out loud 5 times. Emphasize: *Fusion built from scratch; Golden Hippo scaled an existing codebase across 1,000+ brands*.
  - [ ] **10:30 – 11:45**: Review **Fusion Field Platform**: Offline Outbox sync with UUID keys, `connectivity_plus`, timesheet calculators, and Web Portal memory/OOM diagnosis.
  - [ ] **11:45 – 01:00**: Review **Golden Hippo**: Flutter Flavors, single shared codebase, Node.js + AWS S3 build automation cutting turnaround by 30%.
- *(01:00 PM – 02:00 PM: Lunch & Rest)*

---

### ☀️ Afternoon Session (02:00 PM – 05:30 PM): Portal & Mobile Live Coding
- **Goal**: Master the core UI patterns required for the "Portal / Mobile" form factor.
- **Documents to Study**:
  - [senior_portal_mobile_live_coding_master.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/senior_portal_mobile_live_coding_master.md)
- **Action Items**:
  - [ ] **02:00 – 03:15**: Type out **Challenge 1 (Adaptive Master-Detail View)** in VS Code or DartPad. Understand `MediaQuery.sizeOf(context)` vs `LayoutBuilder`.
  - [ ] **03:15 – 04:30**: Type out **Challenge 2 (Virtualized Web Data Table)**. Understand why `ListView.builder` is used instead of a naive `DataTable`.
  - [ ] **04:30 – 05:30**: Review **Challenge 3 (Adaptive Modal)** and **Challenge 6 (Timesheet Shift Calculator with 24h Capping)**.
- *(05:30 PM – 06:30 PM: Break / Walk / Coffee)*

---

### 🌙 Evening Session (06:30 PM – 09:30 PM): Behavioral & Leadership (STAR)
- **Goal**: Prepare for managerial and cross-functional questions.
- **Documents to Study**:
  - [senior_flutter_behavioral_master.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/senior_flutter_behavioral_master.md)
- **Action Items**:
  - [ ] **06:30 – 08:00**: Study **Questions 1 to 6** (Maintaining an existing codebase, backend API deadlocks, designer conflicts, QA blockers, and crash spikes).
  - [ ] **08:00 – 09:30**: Study **Questions 7 to 12** (Mentoring juniors, missing sprint estimates proactively, technical debt trade-offs, and executive communication).

---

## DAY 2: Thursday, September 17 (Engine Internals, System Design & Logic)

### 🌅 Morning Session (09:00 AM – 01:00 PM): Flutter Engine & Technical Q&A
- **Goal**: Master the deep technical questions (Three Trees, BuildContext, Concurrency).
- **Documents to Study**:
  - [flutter_interview_qa_and_coding_master.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/flutter_interview_qa_and_coding_master.md) (Part II: Rounds 1 to 4).
  - [flutter_interview_master_vol2.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/flutter_interview_master_vol2.md) (Section 2: Engine & Dart Internals).
- **Action Items**:
  - [ ] **09:00 – 10:30**: Three Trees (`Widget`, `Element`, `RenderObject`), `Widget.canUpdate()`, `BuildContext` under the hood (it *is* the Element), and `mounted` checks across async gaps.
  - [ ] **10:30 – 11:45**: Concurrency & Event Loop: Microtasks vs Event queue, `Isolate.run()` for heavy JSON/image processing.
  - [ ] **11:45 – 01:00**: BLoC concurrency transformers (`droppable`, `restartable`, `sequential`), Dio `QueuedInterceptor` for token refresh, and Clean Architecture layer contracts.
- *(01:00 PM – 02:00 PM: Lunch & Rest)*

---

### ☀️ Afternoon Session (02:00 PM – 05:30 PM): Logic & Algorithmic Challenges
- **Goal**: Build muscle memory for analytical, DSA, and pure logic problems.
- **Documents to Study**:
  - [dart_algorithms_and_logic_master.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/dart_algorithms_and_logic_master.md)
  - [pure_logic_coding_interview_master.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/pure_logic_coding_interview_master.md)
- **Action Items**:
  - [ ] **02:00 – 03:00**: Merge Overlapping Shift Intervals (Problem 1) & Two Sum (Problem 2).
  - [ ] **03:00 – 04:15**: Trapping Rain Water (Two Pointers) & Product of Array Except Self.
  - [ ] **04:15 – 05:30**: First Missing Positive ($O(1)$ space Cycle Sort) & Gas Station Circuit.
- *(05:30 PM – 06:30 PM: Break / Exercise / Disconnect)*

---

### 🌙 Evening Session (06:30 PM – 09:30 PM): System Design & HR Screening
- **Goal**: Solidify system design architectures and salary/visa communication.
- **Documents to Study**:
  - [flutter_interview_master_vol2.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/flutter_interview_master_vol2.md) (Section 1: System Design).
  - [senior_flutter_interview_process_and_playbook.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/senior_flutter_interview_process_and_playbook.md)
- **Action Items**:
  - [ ] **06:30 – 07:45**: System Design: Battery-efficient GPS tracking (Haversine filters, Android Foreground Services vs iOS background tasks) and Multi-Tenant RBAC.
  - [ ] **07:45 – 08:45**: Review HR negotiation: Immediate availability, UAE Resident status, 18,000–22,000 AED range, and the 2 reverse questions.
  - [ ] **08:45 – 09:30**: Skim [senior_flutter_zero_blindspots.md](file:///Users/irshathahamed/.gemini/antigravity-ide/brain/2f26c0b5-b896-4002-8e2f-a828814bf951/senior_flutter_zero_blindspots.md) (Impeller vs Skia, WasmGC, `runZonedGuarded`).
- **10:00 PM**: **SLEEP EARLY!** Do not study late into the night. Your brain needs rest for sharp recall tomorrow.

---

## DAY 3: Friday, September 18 (Game Day Execution)

```
┌────────────────────────────────────────────────────────────────────────┐
│                   FRIDAY MORNING COUNTDOWN TO 10:00 AM                 │
├──────────────┬─────────────────────────────────────────────────────────┤
│ 07:30 AM     │ Wake up, light breakfast, hydrate                       │
│ 08:30 AM     │ Skim Zero Blindspots & 90-second pitch (30 mins only)   │
│ 09:00 AM     │ Hardware, Camera, Mic & Screen-share setup              │
│ 09:30 AM     │ Deep breathing, quiet room, glass of water              │
│ 10:00 AM     │ INTERVIEW BEGINS — KNOCK IT OUT OF THE PARK!            │
└──────────────┴─────────────────────────────────────────────────────────┘
```

### Detailed Morning Timeline:
- **07:30 AM**: Wake up. Have a light, protein-rich breakfast. Drink a glass of water.
- **08:30 AM – 09:00 AM (Light Warm-Up Only — No Heavy Reading)**:
  - Re-read your **90-second intro** once.
  - Review your **2 questions for them**:
    1. *"Given that this internal application is preparing for its production launch, what are the biggest technical risks or stability hurdles the team is focused on resolving right now?"*
    2. *"How is user traffic split between the mobile app and the portal/tablet interface, and are there plans to introduce more desktop-specific workflows?"*
- **09:00 AM – 09:30 AM (Technical Setup)**:
  - Check your laptop battery (plugged into charger).
  - Test webcam, microphone, and internet connection.
  - Open VS Code with a clean, empty project ready if live coding is asked. Set editor font size to 16–18px (`Cmd + +`).
  - Close all unnecessary browser tabs, Slack, WhatsApp, and email notifications.
- **09:30 AM – 09:55 AM (Mental Centering)**:
  - Put phone on silent.
  - Sit comfortably. Keep a glass of water next to you.
  - Remind yourself: *You have built enterprise platforms from scratch, scaled systems to 1,000+ clients, and you know this material inside out.*
- **10:00 AM**: Join the meeting with a warm smile, positive energy, and ace it!
