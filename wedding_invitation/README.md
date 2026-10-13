# Luxury Islamic Wedding Invitation Microsite

A bespoke, editorial, luxury Islamic wedding invitation microsite for the Nikah of **S. Thaiyeba Tasleema, B.E.** & **S. Irshath Ahamed, B.E.** (Senior Software Engineer, Fusion Groups - UAE).

---

## 🌟 Key Features

1. **Digital Envelope Opening Experience**:
   - Interactive digital envelope with an antique gold wax seal emblem (*Khatam / Monogram TI*).
   - "Open Invitation" cinematic animation with flap unfolding.
   - "Skip Intro" button for accessibility and returning visitors, with session memory.
   - Guest name personalization via URL parameters (`?guest=Name` or `?to=Name`).

2. **Accurate Live Countdown Clock**:
   - Accurately targets **Thursday, 24th December 2026 at 11:30 AM IST (UTC+05:30)**.
   - Computes UTC millisecond differences for 100% precision across all world timezones (India, UAE, UK, US, etc.).
   - Automatically flips to *"Alhamdulillah — The Nikah has begun"* once the ceremony commences.

3. **Ambient Procedural Soundscape (Web Audio API)**:
   - Synthesizes a peaceful, soothing warm ambient acoustic pad/harp soundscape in real-time.
   - Never depends on external audio links or licenses.
   - Supports custom MP3 files via `WEDDING_CONFIG.musicUrl`.
   - Floating audio pill with animated soundwave visualizer.
   - Auto-pauses when the browser tab is hidden to save power and battery.

4. **Add to Calendar Suite**:
   - 1-click direct integration for:
     - **Google Calendar**
     - **Apple Calendar**
     - **Microsoft Outlook**
     - **Universal `.ics` file generation**

5. **Venue & Interactive Navigation**:
   - Displays Prasanna Mahal, Karaikudi.
   - "Get Directions" & "Open in Google Maps" buttons.
   - Embedded responsive Google Map.
   - Dynamic QR Code modal for instant mobile scanning.

6. **WhatsApp & Social Sharing**:
   - 1-click WhatsApp sharing with pre-formatted invitation card details.
   - 1-click copy link with floating visual toast notification.
   - Telegram and Email sharing shortcuts.

8. **Design Language & Accessibility**:
   - Warm Ivory, Champagne, Muted Antique Gold, and Deep Emerald palette.
   - Typography: Google Fonts `Cormorant Garamond` (editorial serif) & `DM Sans` (modern sans-serif) + `Amiri` for Bismillah calligraphy.
   - Full support for `prefers-reduced-motion`.
   - 100% mobile-first responsive (tested on 375px, 390px, 430px, 768px, 1024px, 1440px+).

---

## 🚀 How to Run Locally

### Option 1: Using npx serve (Recommended)
```bash
cd wedding_invitation
npx serve . -l 3000
```
Open `http://localhost:3000` in your browser.

### Option 2: Using Python HTTP Server
```bash
cd wedding_invitation
python3 -m http.server 3000
```
Open `http://localhost:3000`.

---

## ⚙️ Central Configuration (`app.js`)

All event details are centralized in `WEDDING_CONFIG`:
```javascript
const WEDDING_CONFIG = {
  brideName: 'S. Thaiyeba Tasleema',
  brideDegree: 'B.E.',
  groomName: 'S. Irshath Ahamed',
  groomDegree: 'B.E.',
  groomDesignation: 'Senior Software Engineer, Fusion Groups - UAE',
  eventTitle: 'Nikah',
  gregorianDateStr: 'Thursday, 24th December 2026',
  hijriDateStr: 'Hijri 1448 - Rajab 14',
  timeStr: '11:30 AM onwards',
  targetIsoDate: '2026-12-24T11:30:00+05:30',
  venueName: 'Prasanna Mahal',
  venueLocation: 'Near Sri Ram Nagar Railway Gate, Opposite Alagappa PET Ground, Karaikudi.',
  googleMapsDestination: 'Prasanna Mahal, Near Sri Ram Nagar Railway Gate, Opposite Alagappa PET Ground, Karaikudi',
  musicUrl: '/audio/wedding-ambient.m4a'
};
```

---

## 💌 Guest Personalization URL

To share personalized invitations with specific guests or families, append `?guest=` or `?to=` to the link:
```
https://your-invitation-domain.com/?guest=Dr.+Faheem+and+Family
```
The digital envelope will elegantly greet them:
*"Warmly welcoming Dr. Faheem and Family"*.

---

## 🌐 Deploy to Vercel / Netlify / GitHub Pages

This is a static site with zero compilation requirements.
- **Vercel**: Run `vercel` or connect your GitHub repository.
- **Netlify**: Drag and drop the `wedding_invitation` folder into Netlify Drop.
- **GitHub Pages**: Push to repository and enable GitHub Pages in Settings.
