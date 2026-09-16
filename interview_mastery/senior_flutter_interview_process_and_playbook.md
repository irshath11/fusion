# Senior Flutter Developer — Interview Process, Negotiation & Execution Playbook

This playbook covers the **entire end-to-end interview process** for your upcoming role as a **Senior Flutter Developer (Portal/Mobile)** in the UAE / Dubai market. It prepares you for the HR round, technical screening, live pair-programming etiquette, and offer negotiation.

---

## 1. The 5-Stage Interview Process Breakdown

```
┌────────────────────────────────────────────────────────────────────────┐
│                        THE 5 INTERVIEW STAGES                          │
├───────────────────┬────────────────────────────────────────────────────┤
│ Stage 1: Screen   │ HR / Recruiter (15-30 mins) — Visa, AED, Availability│
│ Stage 2: Tech Deep│ Tech Lead (45-60 mins) — Architecture & Internals  │
│ Stage 3: Coding   │ Live Coding / Pair Programming (60 mins)           │
│ Stage 4: Manager  │ Engineering Manager (45 mins) — Culture & Agile    │
│ Stage 5: Offer    │ Director / HR Offer & Contract Negotiation         │
└───────────────────┴────────────────────────────────────────────────────┘
```

---

## 2. Stage 1: HR & Recruiter Screening (UAE / Dubai Specific)

In the UAE and Gulf market, recruiters have strict filter criteria. You must answer these smoothly:

### Q1: "What is your current notice period and availability?"
- **Your Answer**:
  > *"I am immediately available to join. I can complete onboarding and start within 1 to 2 business days."*
  *(This is a huge competitive advantage over candidates who have 30 to 60-day notice periods).*

### Q2: "What is your current visa status in the UAE?"
- **Your Answer**:
  > *"I am a UAE Resident with a valid visa and Emirates ID, and I am fully authorized to work. Transitioning to a company visa or working under an approved contract is straightforward."*

### Q3: "The role is for Dubai / Abu Dhabi and open to contract. Are you open to that?"
- **Your Answer**:
  > *"Yes, absolutely. I am based in the UAE and open to both Dubai-based contracts (such as 6-month extendable contracts) and full-time permanent roles. Relocating or commuting within Dubai/Abu Dhabi is completely fine for me."*

### Q4: "What are your salary expectations?"
- **Strategy**: Never give a single rigid number; give a realistic, senior-level range in **AED (Arab Emirates Dirham)**.
- **Your Answer**:
  > *"Based on my close to 5 years of hands-on experience architecting cross-platform mobile and web portal platforms, and the market standards in Dubai for a Senior Flutter Developer, I am looking in the range of **18,000 to 22,000 AED per month** (or the equivalent daily/monthly contract rate), depending on the total package, medical benefits, and contract duration. However, finding the right technical fit and long-term project impact is my priority, and I am open to a fair offer for the right role."*

---

## 3. Stage 2 & 3: Live Coding & Screen-Share Etiquette

During a live screen-share (Zoom, Google Meet, Teams, or CoderPad):

### The 5 Golden Rules of Live Screen-Share
1. **The "Think Aloud" Protocol**:
   - Never stay silent for more than 15 seconds.
   - Say what you are doing as you type: *"I am creating an immutable state class first so that our BLoC has clean, predictable emissions..."*
2. **Clarify Edge Cases Before Writing Code**:
   - *"Before I begin, should this handle empty lists or null inputs?"*
   - *"On web/portal, should this adapt if the window width drops below 768px?"*
   - *Result*: Interviewers immediately mark you as a Senior Engineer because juniors jump straight into typing without thinking.
3. **What to Do If You Get a Compiler or Syntax Bug**:
   - **Do NOT panic**: Every engineer encounters typos and syntax errors.
   - Read the error message out loud: *"Okay, the analyzer says `The argument type 'String?' cannot be assigned to 'String'`. That's because our entity has a nullable field here—let me add a defensive fallback with `?? ''`."*
   - Showing a calm, methodical debugging mindset is often worth **more points** than writing code with zero typos.
4. **Write at Least One Quick Test or Assertion**:
   - Once your function is written, don't just say *"I'm done."*
   - Say: *"Let me write a quick test case to verify our edge cases with an unclosed 24-hour shift..."*
   - Interviewers love seeing test-driven discipline.
5. **Keep Your Workspace Clean**:
   - Close irrelevant browser tabs and notifications before screen-sharing.
   - Increase font size in VS Code / Android Studio (`Cmd + +`) so the interviewer can read your code easily.

---

## 4. Stage 4: Engineering Manager & Agile Leadership

In the managerial round, they want to know how you operate in a team:

### Q: "How do you run your daily standups and sprint planning?"
- **Your Answer**:
  > *"In our 2-week sprints, we start with Sprint Planning where user stories have clear Definition of Ready (DoR) and Acceptance Criteria. In daily standups, I keep my updates concise: what I completed yesterday, what I am delivering today, and any technical blockers with backend or design.*
  > *During Sprint Retrospectives, I focus on continuous improvement: if a feature was delayed due to third-party API changes, we discuss how we can mock dependencies earlier in the sprint next time."*

---

## 5. Stage 5: High-Impact Reverse Questions to Ask Them

When the interviewer asks: *"Do you have any questions for us?"*, **never say "No, everything was clear."**

Ask 2 or 3 of these high-impact questions to prove your senior mindset:

1. **Architecture & Launch (Targeted to this JD)**:
   > *"Given that this internal application is preparing for its production launch, what are the biggest technical risks or stability hurdles the team is focused on resolving right now?"*
2. **Web Portal vs Mobile Balance**:
   > *"How is user traffic split between the mobile app and the portal/tablet interface, and are there plans to introduce more desktop-specific workflows?"*
3. **Engineering Culture & CI/CD**:
   > *"What does the current automated testing and CI/CD deployment pipeline look like for your staging and production releases?"*
4. **Success Metrics**:
   > *"If I join the team, what would success look like for me in the first 90 days ahead of the production rollout?"*

---

## 6. Pre-Interview Checklist for Friday Morning (10:00 AM)

- [ ] **Hardware & Internet**:
  - Test webcam, microphone, and headphones 30 minutes early.
  - Ensure stable high-speed WiFi (keep a mobile hotspot ready as backup).
- [ ] **Workspace Setup**:
  - Open VS Code or Android Studio with a clean project ready if live coding is requested.
  - Set editor font size to 16px–18px for clear screen-sharing.
  - Put phone on silent mode.
- [ ] **Mindset & Body Language**:
  - Dress professionally (smart casual / collared shirt).
  - Look into the camera when speaking to maintain virtual eye contact.
  - Smile and speak with steady, positive energy.
  - Remember: You built an entire enterprise offline-first platform from scratch in Fusion, and scaled an existing codebase to 1,000+ brands in Golden Hippo. You have already done everything this job requires!
