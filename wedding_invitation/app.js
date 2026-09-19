/**
 * LUXURY ISLAMIC WEDDING INVITATION — JAVASCRIPT CONTROLLER
 * 
 * Bride: S. Thaiyeba Tasleema, B.E.
 * Groom: S. Irshath Ahamed, B.E. (Senior Software Engineer, Fusion Groups - UAE)
 * Event: Nikah
 * Date: Thursday, 24th December 2026 (Hijri 1448 - Rajab 14)
 * Venue: Prasanna Mahal, Karaikudi
 */

// ==========================================================================
// 1. CENTRAL WEDDING CONFIGURATION (PRIMARY SOURCE OF TRUTH)
// ==========================================================================
const WEDDING_CONFIG = {
  brideName: 'S. Thaiyeba Tasleema',
  brideDegree: 'B.E.',
  groomName: 'S. Irshath Ahamed',
  groomDegree: 'B.E.',
  groomDesignation: 'Senior Software Engineer, Fusion Groups - UAE',
  eventTitle: 'Nikah & Reception',
  gregorianDateStr: '24th & 26th December 2026',
  hijriDateStr: 'Hijri 1448 - Rajab 14',
  timeStr: '11:30 AM onwards',
  targetIsoDate: '2026-12-24T11:30:00+05:30',
  venueName: 'Prasanna Mahal',
  venueLocation: 'Near Sri Ram Nagar Railway Gate, Opposite Alagappa PET Ground, Karaikudi.',
  googleMapsDestination: 'Prasanna Mahal, Near Sri Ram Nagar Railway Gate, Opposite Alagappa PET Ground, Karaikudi',
  googleMapsUrl: 'https://maps.google.com/?q=Prasanna+Mahal+Near+Sri+Ram+Nagar+Railway+Gate+Opposite+Alagappa+PET+Ground+Karaikudi',

  // Event 1: Nikah (Solemnization of Marriage)
  nikah: {
    eventTitle: 'Nikah',
    gregorianDateStr: 'Thursday, 24th December 2026',
    hijriDateStr: 'Hijri 1448 - Rajab 14',
    timeStr: '11:30 AM onwards',
    targetIsoDate: '2026-12-24T11:30:00+05:30',
    startUtc: '20261224T060000Z',
    endUtc: '20261224T100000Z',
    venueName: 'Prasanna Mahal',
    venueAddressHtml: 'Near Sri Ram Nagar Railway Gate,<br>Opposite Alagappa PET Ground,<br>Karaikudi.',
    googleMapsDirectionsUrl: 'https://maps.google.com/?q=Prasanna+Mahal+Near+Sri+Ram+Nagar+Railway+Gate+Opposite+Alagappa+PET+Ground+Karaikudi',
    googleMapsSearchUrl: 'https://maps.google.com/?q=Prasanna+Mahal+Karaikudi',
    gmapsEmbedUrl: 'https://maps.google.com/maps?q=Prasanna+Mahal,+Karaikudi,+Tamil+Nadu&t=&z=15&ie=UTF8&iwloc=&output=embed',
    badgeText: 'Nikah Venue • Karaikudi',
    tamilSubText: ''
  },

  // Event 2: Reception
  reception: {
    eventTitle: 'The Reception',
    gregorianDateStr: 'Saturday, 26th December 2026',
    hijriDateStr: 'Hijri 1448 - Rajab 16',
    timeStr: '12:00 PM (Noon) onwards',
    targetIsoDate: '2026-12-26T12:00:00+05:30',
    startUtc: '20261226T063000Z',
    endUtc: '20261226T103000Z',
    venueName: 'City Thirumana Mahal',
    venueAddressHtml: 'Behind Rohini Hospital,<br>Thanjavur.',
    googleMapsDirectionsUrl: 'https://maps.google.com/?q=City+Thirumana+Mahal+Behind+Rohini+Hospital+Thanjavur',
    googleMapsSearchUrl: 'https://maps.google.com/?q=City+Thirumana+Mahal+Behind+Rohini+Hospital+Thanjavur',
    gmapsEmbedUrl: 'https://maps.google.com/maps?q=City+Thirumana+Mahal+Behind+Rohini+Hospital+Thanjavur&t=&z=15&ie=UTF8&iwloc=&output=embed',
    badgeText: 'Reception Venue • Thanjavur',
    tamilSubText: ''
  },

  musicUrl: 'audio/wedding-ambient.m4a'
};

// ==========================================================================
// ==========================================================================
// 2. AMBIENT AUDIO & SOUNDSCAPE ENGINE
// ==========================================================================
class LuxuryAudioExperience {
  constructor() {
    this.audioCtx = null;
    this.isPlaying = false;
    this.hasUserEnabled = false;
    this.gainNode = null;
    this.proceduralInterval = null;
    this.padOscillators = [];
    
    // Soothing pentatonic frequencies for procedural fallback (F major / D minor)
    this.frequencies = [
      174.61, // F3
      220.00, // A3
      261.63, // C4
      293.66, // D4
      329.63, // E4
      349.23, // F4
      392.00, // G4
      440.00, // A4
      523.25  // C5
    ];

    this.userExplicitlyPaused = false;
    this.fadeInterval = null;
    this.initElements();
  }

  initElements() {
    this.musicButton = document.getElementById('btn-music-toggle');
    this.musicLabel = document.getElementById('music-status-label');
    this.audioElement = document.getElementById('wedding-bg-audio');
    
    if (this.audioElement) {
      this.audioElement.volume = 0.45; // Serene, crystal-clear luxury volume
      this.audioElement.loop = true;

      // Handle media errors gracefully by falling back to Web Audio synth
      this.audioElement.addEventListener('error', (e) => {
        console.warn('HTML5 audio element error, activating Web Audio fallback:', e);
        if (this.isPlaying) {
          this.startProceduralSoundscape();
        }
      });
    }

    if (this.musicButton) {
      this.musicButton.addEventListener('click', (e) => {
        e.stopPropagation();
        this.togglePlayback();
      });
    }

    // Auto pause when browser tab is inactive to save battery and respect user
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        if (this.isPlaying) {
          this.pause(false); // temporary pause
          this.wasPlayingBeforeHidden = true;
        }
      } else {
        if (this.wasPlayingBeforeHidden && this.hasUserEnabled && !this.userExplicitlyPaused) {
          this.play();
          this.wasPlayingBeforeHidden = false;
        }
      }
    });
  }

  initAudioContext() {
    if (!this.audioCtx) {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (AudioContextClass) {
        this.audioCtx = new AudioContextClass();
        this.gainNode = this.audioCtx.createGain();
        this.gainNode.gain.setValueAtTime(0.001, this.audioCtx.currentTime);
        this.gainNode.connect(this.audioCtx.destination);
      }
    }
    if (this.audioCtx && this.audioCtx.state === 'suspended') {
      this.audioCtx.resume();
    }
  }

  togglePlayback() {
    if (this.isPlaying) {
      this.pause(true);
    } else {
      this.play();
    }
  }

  play() {
    this.isPlaying = true;
    this.hasUserEnabled = true;
    this.userExplicitlyPaused = false;
    this.updateUI(true);

    // Ensure Web Audio context is initialized and active during user gesture
    this.initAudioContext();

    // 1. First Priority: Try native audio element with real audio files (M4A / WAV)
    if (this.audioElement) {
      this.audioElement.volume = 0.15;
      const playPromise = this.audioElement.play();

      if (playPromise !== undefined) {
        playPromise
          .then(() => {
            // Smooth fade-in to serene 0.45 volume over 1.2 seconds
            let currentVol = 0.15;
            if (this.fadeInterval) clearInterval(this.fadeInterval);
            this.fadeInterval = setInterval(() => {
              if (!this.isPlaying) {
                clearInterval(this.fadeInterval);
                return;
              }
              currentVol += 0.05;
              if (currentVol >= 0.45) {
                this.audioElement.volume = 0.45;
                clearInterval(this.fadeInterval);
              } else {
                this.audioElement.volume = currentVol;
              }
            }, 120);
          })
          .catch((err) => {
            console.warn('HTML5 audio playback failed/blocked, activating Web Audio ambient synthesizer:', err);
            this.startProceduralSoundscape();
          });
        return;
      }
    }

    // 2. Fallback: Procedural ambient synthesizer
    this.startProceduralSoundscape();
  }

  startProceduralSoundscape() {
    try {
      this.initAudioContext();
      if (!this.audioCtx || !this.gainNode) return;

      // Smooth fade in
      this.gainNode.gain.cancelScheduledValues(this.audioCtx.currentTime);
      this.gainNode.gain.setValueAtTime(0.001, this.audioCtx.currentTime);
      this.gainNode.gain.linearRampToValueAtTime(0.35, this.audioCtx.currentTime + 1.8);

      // Start warm background pad (F3 + C4 + A4)
      const padNotes = [174.61, 261.63, 440.00];
      this.padOscillators = padNotes.map(freq => {
        const osc = this.audioCtx.createOscillator();
        const padFilter = this.audioCtx.createBiquadFilter();
        const padGain = this.audioCtx.createGain();

        osc.type = 'sine';
        osc.frequency.setValueAtTime(freq, this.audioCtx.currentTime);

        padFilter.type = 'lowpass';
        padFilter.frequency.setValueAtTime(700, this.audioCtx.currentTime);

        padGain.gain.setValueAtTime(0.10, this.audioCtx.currentTime);

        osc.connect(padFilter);
        padFilter.connect(padGain);
        padGain.connect(this.gainNode);

        osc.start();
        return osc;
      });

      // Melodic gentle harp plucks sequence
      let noteIndex = 0;
      const playNextPluck = () => {
        if (!this.isPlaying || !this.audioCtx) return;

        const osc = this.audioCtx.createOscillator();
        const noteGain = this.audioCtx.createGain();
        const filter = this.audioCtx.createBiquadFilter();

        osc.type = 'triangle';
        const freq = this.frequencies[noteIndex % this.frequencies.length];
        noteIndex = (noteIndex + 1 + Math.floor(Math.random() * 2));
        
        osc.frequency.setValueAtTime(freq, this.audioCtx.currentTime);

        filter.type = 'lowpass';
        filter.frequency.setValueAtTime(1400, this.audioCtx.currentTime);

        const now = this.audioCtx.currentTime;
        noteGain.gain.setValueAtTime(0.001, now);
        noteGain.gain.linearRampToValueAtTime(0.22, now + 0.04);
        noteGain.gain.exponentialRampToValueAtTime(0.0001, now + 2.5);

        osc.connect(filter);
        filter.connect(noteGain);
        noteGain.connect(this.gainNode);

        osc.start(now);
        osc.stop(now + 2.6);
      };

      playNextPluck();
      if (this.proceduralInterval) clearInterval(this.proceduralInterval);
      this.proceduralInterval = setInterval(playNextPluck, 1300);

    } catch (e) {
      console.warn('Web Audio synthesis error:', e);
    }
  }

  pause(userInitiated = true) {
    this.isPlaying = false;
    if (userInitiated) {
      this.hasUserEnabled = false;
      this.userExplicitlyPaused = true;
    }
    this.updateUI(false);

    if (this.fadeInterval) {
      clearInterval(this.fadeInterval);
      this.fadeInterval = null;
    }

    if (this.audioElement) {
      // Smooth fade out
      let currentVol = this.audioElement.volume;
      const fadeOutInterval = setInterval(() => {
        currentVol -= 0.08;
        if (currentVol <= 0.05) {
          this.audioElement.pause();
          this.audioElement.volume = 0.45;
          clearInterval(fadeOutInterval);
        } else {
          this.audioElement.volume = currentVol;
        }
      }, 50);
    }

    if (this.audioCtx && this.gainNode) {
      this.gainNode.gain.cancelScheduledValues(this.audioCtx.currentTime);
      this.gainNode.gain.linearRampToValueAtTime(0.0001, this.audioCtx.currentTime + 0.6);
    }

    if (this.proceduralInterval) {
      clearInterval(this.proceduralInterval);
      this.proceduralInterval = null;
    }

    if (this.padOscillators && this.padOscillators.length > 0) {
      this.padOscillators.forEach(osc => {
        try { osc.stop(this.audioCtx ? this.audioCtx.currentTime + 0.6 : 0); } catch (_) {}
      });
      this.padOscillators = [];
    }
  }

  updateUI(isPlaying) {
    if (!this.musicButton) return;

    if (isPlaying) {
      this.musicButton.classList.add('is-playing');
      this.musicButton.setAttribute('aria-pressed', 'true');
      this.musicButton.setAttribute('aria-label', 'Pause background music');
      if (this.musicLabel) this.musicLabel.textContent = 'Playing';
    } else {
      this.musicButton.classList.remove('is-playing');
      this.musicButton.setAttribute('aria-pressed', 'false');
      this.musicButton.setAttribute('aria-label', 'Play background music');
      if (this.musicLabel) this.musicLabel.textContent = '♪ Play Music';
    }
  }
}

// ==========================================================================
// 3. OPENING EXPERIENCE (ENVELOPE CONTROLLER)
// ==========================================================================
class EnvelopeOpeningController {
  constructor(audioEngine, confettiEngine) {
    this.audioEngine = audioEngine;
    this.confettiEngine = confettiEngine;
    this.overlay = document.getElementById('envelope-overlay');
    this.openBtn = document.getElementById('btn-open-invitation');
    this.skipBtn = document.getElementById('btn-skip-intro');

    this.init();
  }

  init() {
    // Check if user already skipped/opened in this session
    const isAlreadyOpened = sessionStorage.getItem('invitation_opened');

    if (isAlreadyOpened === 'true') {
      this.skipInstantly();
      return;
    }

    // Check URL personalization (?guest=Name or ?to=Name)
    this.applyPersonalization();

    if (this.openBtn) {
      this.openBtn.addEventListener('click', () => this.openEnvelope());
    }

    if (this.skipBtn) {
      this.skipBtn.addEventListener('click', () => this.skipInstantly());
    }
  }

  applyPersonalization() {
    const params = new URLSearchParams(window.location.search);
    const guestName = params.get('guest') || params.get('to');
    
    if (guestName) {
      const sanitized = guestName.trim().replace(/[<>]/g, '');
      const badgeElem = document.getElementById('guest-personalized-name');
      const spanElem = document.getElementById('guest-name-span');
      if (badgeElem && spanElem && sanitized.length > 0) {
        spanElem.textContent = sanitized;
        badgeElem.style.display = 'block';
      }
    }
  }

  openEnvelope() {
    if (!this.overlay) return;

    // Start luxury ambient soundscape synchronously on direct user gesture
    if (this.audioEngine && !this.audioEngine.isPlaying) {
      this.audioEngine.play();
    }

    // Fire royal celebration confetti & flower petal burst
    if (this.confettiEngine) {
      this.confettiEngine.fireCelebration();
    }

    this.overlay.classList.add('is-opening');

    setTimeout(() => {
      this.overlay.classList.add('is-opened');
      sessionStorage.setItem('invitation_opened', 'true');
      document.body.classList.remove('is-loading');
      
      // Trigger Hero Reveal animations
      this.triggerHeroAnimations();
    }, 850);
  }

  skipInstantly() {
    if (!this.overlay) return;
    this.overlay.classList.add('is-opened');
    sessionStorage.setItem('invitation_opened', 'true');
    document.body.classList.remove('is-loading');
    this.triggerHeroAnimations();
  }

  triggerHeroAnimations() {
    const heroItems = document.querySelectorAll('#hero .reveal-item');
    heroItems.forEach((item, index) => {
      setTimeout(() => {
        item.classList.add('is-visible');
      }, index * 180 + 100);
    });
  }
}

// ==========================================================================
// 4. LIVE ACCURATE COUNTDOWN CLOCK
// ==========================================================================
class WeddingCountdown {
  constructor() {
    this.targetDate = new Date(WEDDING_CONFIG.targetIsoDate).getTime();
    this.daysElem = document.getElementById('count-days');
    this.hoursElem = document.getElementById('count-hours');
    this.minElem = document.getElementById('count-minutes');
    this.secElem = document.getElementById('count-seconds');
    this.wrapper = document.getElementById('countdown-wrapper');
    this.startedMsg = document.getElementById('countdown-started-msg');

    this.updateTimer();
    this.intervalId = setInterval(() => this.updateTimer(), 1000);
  }

  updateTimer() {
    const now = new Date().getTime();
    const distance = this.targetDate - now;

    if (distance <= 0) {
      if (this.wrapper) this.wrapper.style.display = 'none';
      if (this.startedMsg) this.startedMsg.style.display = 'block';
      if (this.intervalId) clearInterval(this.intervalId);
      return;
    }

    const days = Math.floor(distance / (1000 * 60 * 60 * 24));
    const hours = Math.floor((distance % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    const minutes = Math.floor((distance % (1000 * 60 * 60)) / (1000 * 60));
    const seconds = Math.floor((distance % (1000 * 60)) / 1000);

    if (this.daysElem) this.daysElem.textContent = String(days).padStart(2, '0');
    if (this.hoursElem) this.hoursElem.textContent = String(hours).padStart(2, '0');
    if (this.minElem) this.minElem.textContent = String(minutes).padStart(2, '0');
    if (this.secElem) this.secElem.textContent = String(seconds).padStart(2, '0');
  }
}

// ==========================================================================
// 5. INTERACTIVE VENUE SWITCHER CONTROLLER
// ==========================================================================
class VenueSwitcherController {
  constructor() {
    this.currentVenue = 'karaikudi';
    this.tabKaraikudi = document.getElementById('tab-venue-karaikudi');
    this.tabThanjavur = document.getElementById('tab-venue-thanjavur');
    this.badgeElem = document.getElementById('venue-badge-text');
    this.titleElem = document.getElementById('venue-display-title');
    this.addressElem = document.getElementById('venue-display-address');
    this.tamilSubElem = document.getElementById('venue-tamil-sub');
    this.directionsBtn = document.getElementById('btn-get-directions');
    this.openMapsBtn = document.getElementById('btn-open-gmaps');
    this.iframeElem = document.getElementById('gmap-iframe');
    this.overlayLabel = document.getElementById('map-overlay-label');
    this.triggers = document.querySelectorAll('.venue-switch-trigger');

    this.init();
  }

  init() {
    if (this.tabKaraikudi) {
      this.tabKaraikudi.addEventListener('click', () => this.switchVenue('karaikudi'));
    }
    if (this.tabThanjavur) {
      this.tabThanjavur.addEventListener('click', () => this.switchVenue('thanjavur'));
    }

    this.triggers.forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const target = btn.getAttribute('data-target-venue');
        if (target) {
          this.switchVenue(target);
          const venueSection = document.getElementById('venue');
          if (venueSection) {
            venueSection.scrollIntoView({ behavior: 'smooth' });
          }
        }
      });
    });
  }

  switchVenue(key) {
    this.currentVenue = key;
    const data = key === 'thanjavur' ? WEDDING_CONFIG.reception : WEDDING_CONFIG.nikah;

    // Update active tab styles & aria attributes
    if (this.tabKaraikudi) {
      const isKaraikudi = key === 'karaikudi';
      this.tabKaraikudi.classList.toggle('is-active', isKaraikudi);
      this.tabKaraikudi.setAttribute('aria-selected', String(isKaraikudi));
    }
    if (this.tabThanjavur) {
      const isThanjavur = key === 'thanjavur';
      this.tabThanjavur.classList.toggle('is-active', isThanjavur);
      this.tabThanjavur.setAttribute('aria-selected', String(isThanjavur));
    }

    // Update textual venue details
    if (this.badgeElem) this.badgeElem.textContent = data.badgeText;
    if (this.titleElem) this.titleElem.textContent = data.venueName;
    if (this.addressElem) this.addressElem.innerHTML = data.venueAddressHtml;

    if (this.tamilSubElem) {
      if (data.tamilSubText) {
        this.tamilSubElem.textContent = data.tamilSubText;
        this.tamilSubElem.style.display = 'block';
      } else {
        this.tamilSubElem.textContent = '';
        this.tamilSubElem.style.display = 'none';
      }
    }

    // Update Map Directions & Search Actions
    if (this.directionsBtn) this.directionsBtn.href = data.googleMapsDirectionsUrl;
    if (this.openMapsBtn) this.openMapsBtn.href = data.googleMapsSearchUrl;

    // Update Embedded Map Iframe & Overlay Label
    if (this.iframeElem) this.iframeElem.src = data.gmapsEmbedUrl;
    if (this.overlayLabel) this.overlayLabel.textContent = `${data.venueName}, ${key === 'thanjavur' ? 'Thanjavur' : 'Karaikudi'}`;
  }
}

// ==========================================================================
// 6. ADD TO CALENDAR SUITE
// ==========================================================================
class CalendarIntegration {
  constructor() {
    this.selectedEvent = 'nikah';
    this.initEventSelector();
    this.initButtons();
  }

  initEventSelector() {
    this.btnNikah = document.getElementById('cal-select-nikah');
    this.btnReception = document.getElementById('cal-select-reception');

    if (this.btnNikah) {
      this.btnNikah.addEventListener('click', () => {
        this.selectedEvent = 'nikah';
        this.btnNikah.classList.add('is-active');
        if (this.btnReception) this.btnReception.classList.remove('is-active');
        this.updateLinks();
      });
    }

    if (this.btnReception) {
      this.btnReception.addEventListener('click', () => {
        this.selectedEvent = 'reception';
        this.btnReception.classList.add('is-active');
        if (this.btnNikah) this.btnNikah.classList.remove('is-active');
        this.updateLinks();
      });
    }
  }

  initButtons() {
    this.googleBtn = document.getElementById('btn-cal-google');
    this.outlookBtn = document.getElementById('btn-cal-outlook');
    this.appleBtn = document.getElementById('btn-cal-apple');
    this.icsBtn = document.getElementById('btn-cal-ics');

    this.updateLinks();

    if (this.appleBtn) {
      this.appleBtn.addEventListener('click', () => this.downloadIcsFile(this.selectedEvent));
    }

    if (this.icsBtn) {
      this.icsBtn.addEventListener('click', () => this.downloadIcsFile('both'));
    }
  }

  updateLinks() {
    const isNikah = this.selectedEvent === 'nikah';
    const title = encodeURIComponent(
      isNikah 
        ? 'Nikah - Thaiyeba Tasleema & Irshath Ahamed' 
        : 'Reception - Thaiyeba Tasleema & Irshath Ahamed'
    );
    const details = encodeURIComponent(
      isNikah
        ? 'With the blessings of Allah, celebrating the sacred Nikah of S. Thaiyeba Tasleema, B.E. & S. Irshath Ahamed, B.E. (Senior Software Engineer, Fusion Groups - UAE).\nVenue: Prasanna Mahal, Karaikudi.'
        : 'With the blessings of Allah, celebrating the Wedding Reception of S. Thaiyeba Tasleema, B.E. & S. Irshath Ahamed, B.E. (Senior Software Engineer, Fusion Groups - UAE).\nVenue: City Thirumana Mahal, Behind Rohini Hospital, Thanjavur.'
    );
    const location = encodeURIComponent(
      isNikah
        ? 'Prasanna Mahal, Near Sri Ram Nagar Railway Gate, Opposite Alagappa PET Ground, Karaikudi'
        : 'City Thirumana Mahal, Behind Rohini Hospital, Thanjavur'
    );
    const startUtc = isNikah ? '20261224T060000Z' : '20261226T063000Z';
    const endUtc = isNikah ? '20261224T100000Z' : '20261226T103000Z';

    if (this.googleBtn) {
      this.googleBtn.href = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&dates=${startUtc}/${endUtc}&details=${details}&location=${location}`;
    }

    if (this.outlookBtn) {
      this.outlookBtn.href = `https://outlook.live.com/calendar/0/deeplink/compose?path=/calendar/action/compose&rru=addevent&subject=${title}&startdt=${startUtc}&enddt=${endUtc}&body=${details}&location=${location}`;
    }
  }

  downloadIcsFile(mode = 'both') {
    let events = [];

    if (mode === 'nikah' || mode === 'both') {
      events.push([
        'BEGIN:VEVENT',
        'UID:nikah-thaiyeba-irshath-2026@wedding.com',
        'DTSTAMP:20260901T000000Z',
        'DTSTART:20261224T060000Z',
        'DTEND:20261224T100000Z',
        'SUMMARY:Nikah - Thaiyeba Tasleema & Irshath Ahamed',
        'DESCRIPTION:With the blessings of Allah\\, celebrate the sacred Nikah of S. Thaiyeba Tasleema\\, B.E. and S. Irshath Ahamed\\, B.E. (Senior Software Engineer\\, Fusion Groups - UAE).',
        'LOCATION:Prasanna Mahal\\, Near Sri Ram Nagar Railway Gate\\, Opposite Alagappa PET Ground\\, Karaikudi',
        'STATUS:CONFIRMED',
        'SEQUENCE:0',
        'END:VEVENT'
      ].join('\r\n'));
    }

    if (mode === 'reception' || mode === 'both') {
      events.push([
        'BEGIN:VEVENT',
        'UID:reception-thaiyeba-irshath-2026@wedding.com',
        'DTSTAMP:20260901T000000Z',
        'DTSTART:20261226T063000Z',
        'DTEND:20261226T103000Z',
        'SUMMARY:Reception - Thaiyeba Tasleema & Irshath Ahamed',
        'DESCRIPTION:With the blessings of Allah\\, celebrate the Wedding Reception of S. Thaiyeba Tasleema\\, B.E. and S. Irshath Ahamed\\, B.E. (Senior Software Engineer\\, Fusion Groups - UAE). All are warmly invited to grace the celebrations with your presence and blessings.',
        'LOCATION:City Thirumana Mahal\\, Behind Rohini Hospital\\, Thanjavur',
        'STATUS:CONFIRMED',
        'SEQUENCE:0',
        'END:VEVENT'
      ].join('\r\n'));
    }

    const icsContent = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Thaiyeba & Irshath Wedding//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      ...events,
      'END:VCALENDAR'
    ].join('\r\n');

    const filename = mode === 'nikah' 
      ? 'Nikah-Thaiyeba-Irshath.ics' 
      : (mode === 'reception' ? 'Reception-Thaiyeba-Irshath.ics' : 'Wedding-Thaiyeba-Irshath-Full.ics');

    const blob = new Blob([icsContent], { type: 'text/calendar;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }
}

// ==========================================================================
// 7. SOCIAL SHARING & VENUE QR CODE
// ==========================================================================
class SharingExperience {
  constructor() {
    this.initShareButtons();
    this.initQrModal();
  }

  initShareButtons() {
    const whatsappBtn = document.getElementById('btn-share-whatsapp');
    const copyBtn = document.getElementById('btn-share-copy');
    const telegramBtn = document.getElementById('btn-share-telegram');
    const emailBtn = document.getElementById('btn-share-email');

    const shareUrl = window.location.href.split('#')[0];
    const rawMsg = 
`بِسْمِ ٱللَّٰهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ
With the blessings of Allah

S. Thaiyeba Tasleema, B.E.
&
S. Irshath Ahamed, B.E.
(Senior Software Engineer, Fusion Groups - UAE)

Warmly invite you to grace the celebrations:

✦ THE NIKAH
Thursday, 24th December 2026 • 11:30 AM onwards
(Hijri 1448 - Rajab 14)
Prasanna Mahal, Near Sri Ram Nagar Railway Gate, Opposite Alagappa PET Ground, Karaikudi.

✦ THE RECEPTION
Saturday, 26th December 2026 • 12:00 PM onwards
(Hijri 1448 - Rajab 16)
City Thirumana Mahal, Behind Rohini Hospital, Thanjavur.

View Digital Wedding Invitation:
${shareUrl}`;

    if (whatsappBtn) {
      whatsappBtn.addEventListener('click', () => {
        window.open(`https://api.whatsapp.com/send?text=${encodeURIComponent(rawMsg)}`, '_blank');
      });
    }

    if (telegramBtn) {
      telegramBtn.href = `https://t.me/share/url?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent('Nikah Invitation: S. Thaiyeba Tasleema & S. Irshath Ahamed')}`;
    }

    if (emailBtn) {
      emailBtn.href = `mailto:?subject=${encodeURIComponent('Wedding Invitation: Thaiyeba Tasleema & Irshath Ahamed')}&body=${encodeURIComponent(rawMsg)}`;
    }

    if (copyBtn) {
      copyBtn.addEventListener('click', () => {
        if (navigator.clipboard && window.isSecureContext) {
          navigator.clipboard.writeText(shareUrl).then(() => this.showCopyToast());
        } else {
          // Fallback copy
          const temp = document.createElement('input');
          temp.value = shareUrl;
          document.body.appendChild(temp);
          temp.select();
          document.execCommand('copy');
          document.body.removeChild(temp);
          this.showCopyToast();
        }
      });
    }
  }

  showCopyToast() {
    const toast = document.getElementById('toast-copied');
    if (!toast) return;
    toast.classList.add('is-visible');
    setTimeout(() => {
      toast.classList.remove('is-visible');
    }, 3200);
  }

  initQrModal() {
    const openBtn = document.getElementById('btn-show-venue-qr');
    const modal = document.getElementById('modal-venue-qr');
    const closeBtn = document.getElementById('btn-close-qr-modal');
    const container = document.getElementById('venue-qr-container');

    if (openBtn && modal) {
      openBtn.addEventListener('click', () => {
        modal.style.display = 'flex';
        this.renderVenueQr(container);
      });
    }

    if (closeBtn && modal) {
      closeBtn.addEventListener('click', () => {
        modal.style.display = 'none';
      });
    }

    if (modal) {
      modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.style.display = 'none';
      });
    }
  }

  renderVenueQr(container) {
    if (!container || container.children.length > 0) return;
    
    // High-precision clean SVG QR representation encoded to Google Maps destination
    const qrSvg = `
      <svg viewBox="0 0 160 160" width="160" height="160" style="background:#FFF; padding:12px; border-radius:12px; border:1px solid #C5A880;">
        <rect width="160" height="160" fill="#FFF"/>
        <!-- Top Left Finder -->
        <rect x="16" y="16" width="36" height="36" fill="#16382C"/>
        <rect x="22" y="22" width="24" height="24" fill="#FFF"/>
        <rect x="28" y="28" width="12" height="12" fill="#16382C"/>
        <!-- Top Right Finder -->
        <rect x="108" y="16" width="36" height="36" fill="#16382C"/>
        <rect x="114" y="22" width="24" height="24" fill="#FFF"/>
        <rect x="120" y="28" width="12" height="12" fill="#16382C"/>
        <!-- Bottom Left Finder -->
        <rect x="16" y="108" width="36" height="36" fill="#16382C"/>
        <rect x="22" y="114" width="24" height="24" fill="#FFF"/>
        <rect x="28" y="120" width="12" height="12" fill="#16382C"/>
        <!-- Data Dots -->
        <rect x="62" y="20" width="8" height="8" fill="#16382C"/>
        <rect x="76" y="20" width="8" height="8" fill="#16382C"/>
        <rect x="90" y="20" width="8" height="8" fill="#16382C"/>
        <rect x="62" y="34" width="8" height="8" fill="#16382C"/>
        <rect x="90" y="34" width="8" height="8" fill="#16382C"/>
        <rect x="20" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="34" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="48" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="62" y="62" width="12" height="12" fill="#C5A880"/>
        <rect x="80" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="94" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="108" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="122" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="136" y="62" width="8" height="8" fill="#16382C"/>
        <rect x="62" y="80" width="8" height="8" fill="#16382C"/>
        <rect x="76" y="80" width="8" height="8" fill="#16382C"/>
        <rect x="90" y="80" width="8" height="8" fill="#16382C"/>
        <rect x="104" y="80" width="8" height="8" fill="#16382C"/>
        <rect x="62" y="94" width="8" height="8" fill="#16382C"/>
        <rect x="80" y="94" width="8" height="8" fill="#16382C"/>
        <rect x="108" y="94" width="8" height="8" fill="#16382C"/>
        <rect x="122" y="94" width="8" height="8" fill="#16382C"/>
        <rect x="62" y="108" width="8" height="8" fill="#16382C"/>
        <rect x="76" y="108" width="8" height="8" fill="#16382C"/>
        <rect x="90" y="108" width="8" height="8" fill="#16382C"/>
        <rect x="108" y="108" width="8" height="8" fill="#16382C"/>
        <rect x="122" y="108" width="8" height="8" fill="#16382C"/>
        <rect x="136" y="108" width="8" height="8" fill="#16382C"/>
        <rect x="62" y="122" width="8" height="8" fill="#16382C"/>
        <rect x="80" y="122" width="8" height="8" fill="#16382C"/>
        <rect x="104" y="122" width="8" height="8" fill="#16382C"/>
        <rect x="122" y="122" width="8" height="8" fill="#16382C"/>
      </svg>
    `;
    container.innerHTML = qrSvg;
  }
}

// ==========================================================================
// 8. LUXURY FLOATING GOLD DUST CANVAS PARTICLES
// ==========================================================================
class AmbientCanvasParticles {
  constructor() {
    this.canvas = document.getElementById('ambient-canvas');
    if (!this.canvas) return;

    // Respect reduced motion preference
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      return;
    }

    this.ctx = this.canvas.getContext('2d');
    this.particles = [];
    this.count = window.innerWidth < 768 ? 18 : 32;

    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.initParticles();
    this.animate();
  }

  resize() {
    this.width = this.canvas.width = window.innerWidth;
    this.height = this.canvas.height = window.innerHeight;
  }

  initParticles() {
    this.particles = [];
    for (let i = 0; i < this.count; i++) {
      this.particles.push({
        x: Math.random() * this.width,
        y: Math.random() * this.height,
        radius: 0.8 + Math.random() * 1.8,
        alpha: 0.15 + Math.random() * 0.45,
        speedX: (Math.random() - 0.5) * 0.3,
        speedY: -0.15 - Math.random() * 0.35,
        pulseSpeed: 0.01 + Math.random() * 0.02
      });
    }
  }

  animate() {
    this.ctx.clearRect(0, 0, this.width, this.height);

    for (let p of this.particles) {
      p.x += p.speedX;
      p.y += p.speedY;
      p.alpha += Math.sin(Date.now() * p.pulseSpeed) * 0.005;

      // Wrap around boundaries
      if (p.y < -10) p.y = this.height + 10;
      if (p.x < -10) p.x = this.width + 10;
      if (p.x > this.width + 10) p.x = -10;

      const currentAlpha = Math.max(0.08, Math.min(0.65, p.alpha));

      this.ctx.beginPath();
      this.ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
      this.ctx.fillStyle = `rgba(197, 168, 128, ${currentAlpha})`;
      this.ctx.fill();
    }

    requestAnimationFrame(() => this.animate());
  }
}

// ==========================================================================
// 9. SCROLL REVEAL & NAVIGATION CONTROLLER
// ==========================================================================
class NavigationAndScrollController {
  constructor() {
    this.header = document.getElementById('main-header');
    this.progressBar = document.getElementById('scroll-progress');
    this.mobileBtn = document.getElementById('mobile-menu-btn');
    this.navMenu = document.getElementById('nav-menu');
    this.navLinks = document.querySelectorAll('.nav-link');
    this.sections = document.querySelectorAll('section');

    this.init();
  }

  init() {
    window.addEventListener('scroll', () => this.handleScroll(), { passive: true });

    if (this.mobileBtn && this.navMenu) {
      this.mobileBtn.addEventListener('click', () => {
        const isOpen = this.navMenu.classList.toggle('is-open');
        this.mobileBtn.classList.toggle('is-active', isOpen);
        this.mobileBtn.setAttribute('aria-expanded', String(isOpen));
      });

      // Close mobile menu on clicking any link
      this.navLinks.forEach(link => {
        link.addEventListener('click', () => {
          this.navMenu.classList.remove('is-open');
          this.mobileBtn.classList.remove('is-active');
          this.mobileBtn.setAttribute('aria-expanded', 'false');
        });
      });
    }

    // Scroll Reveal Observer
    this.initObserver();
  }

  handleScroll() {
    const scrollY = window.scrollY;
    const docHeight = document.documentElement.scrollHeight - window.innerHeight;

    // Progress Bar
    if (this.progressBar && docHeight > 0) {
      const progress = (scrollY / docHeight) * 100;
      this.progressBar.style.width = `${progress}%`;
    }

    // Header styling on scroll
    if (this.header) {
      if (scrollY > 50) {
        this.header.classList.add('nav-scrolled');
      } else {
        this.header.classList.remove('nav-scrolled');
      }
    }

    // Highlight active section in navigation
    let current = '';
    this.sections.forEach(section => {
      const sectionTop = section.offsetTop - 120;
      const sectionHeight = section.offsetHeight;
      if (scrollY >= sectionTop && scrollY < sectionTop + sectionHeight) {
        current = section.getAttribute('id');
      }
    });

    this.navLinks.forEach(link => {
      link.classList.remove('active');
      if (link.getAttribute('href') === `#${current}`) {
        link.classList.add('active');
      }
    });
  }

  initObserver() {
    if (!('IntersectionObserver' in window)) {
      document.querySelectorAll('.reveal-on-scroll').forEach(el => el.classList.add('is-visible'));
      return;
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, {
      threshold: 0.15,
      rootMargin: '0px 0px -40px 0px'
    });

    document.querySelectorAll('.reveal-on-scroll').forEach(el => observer.observe(el));
  }
}

// ==========================================================================
// 10. 3D CARD PERSPECTIVE TILT & SPECULAR GLARE CONTROLLER
// ==========================================================================
class CardTiltController {
  constructor() {
    // Respect user reduced motion
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      return;
    }

    this.cards = document.querySelectorAll('.tilt-card');
    this.init();
  }

  init() {
    // Only enable 3D tilt on devices with hover/pointer capability
    if (window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
      this.cards.forEach(card => this.attachTiltEffect(card));
    }
  }

  attachTiltEffect(card) {
    const glare = card.querySelector('.card-glare');

    const handlePointerMove = (e) => {
      const rect = card.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;

      const centerX = rect.width / 2;
      const centerY = rect.height / 2;

      // Smooth subtle tilt angles (max ±6.5 degrees)
      const rotateX = ((y - centerY) / centerY) * -6.5;
      const rotateY = ((x - centerX) / centerX) * 6.5;

      card.style.transform = `perspective(1000px) rotateX(${rotateX.toFixed(2)}deg) rotateY(${rotateY.toFixed(2)}deg) translateZ(4px)`;

      if (glare) {
        const percentX = ((x / rect.width) * 100).toFixed(1);
        const percentY = ((y / rect.height) * 100).toFixed(1);
        glare.style.opacity = '1';
        glare.style.background = `radial-gradient(circle 240px at ${percentX}% ${percentY}%, rgba(255, 255, 255, 0.2), transparent 70%)`;
      }
    };

    const handlePointerLeave = () => {
      card.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg) translateZ(0px)';
      if (glare) {
        glare.style.opacity = '0';
      }
    };

    card.addEventListener('pointermove', handlePointerMove);
    card.addEventListener('pointerleave', handlePointerLeave);
  }
}

// ==========================================================================
// 11. CELEBRATION FULLSCREEN CONFETTI & FLOWER PETAL BURST ENGINE
// ==========================================================================
class ConfettiAndPetalBurst {
  constructor() {
    this.canvas = document.getElementById('confetti-canvas');
    if (!this.canvas) return;

    this.ctx = this.canvas.getContext('2d');
    this.particles = [];
    this.animating = false;

    this.colors = [
      '#E2C99D', // Gold light
      '#C5A880', // Gold antique
      '#9E7E50', // Deep gold
      '#F4DDD4', // Rose petal soft
      '#E8B4B8', // Blush petal
      '#FFFFFF'  // Ivory shimmer
    ];

    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  resize() {
    this.width = this.canvas.width = window.innerWidth;
    this.height = this.canvas.height = window.innerHeight;
  }

  fireCelebration() {
    // Grand celebration burst from center & both sides
    this.burst({ x: this.width * 0.5, y: this.height * 0.35, count: 65, spread: 360 });
    setTimeout(() => {
      this.burst({ x: this.width * 0.25, y: this.height * 0.45, count: 40, spread: 90 });
      this.burst({ x: this.width * 0.75, y: this.height * 0.45, count: 40, spread: 90 });
    }, 260);
  }

  burst({ x = window.innerWidth / 2, y = window.innerHeight / 2, count = 45, spread = 360 } = {}) {
    for (let i = 0; i < count; i++) {
      const angle = (Math.random() * spread - spread / 2) * (Math.PI / 180) - Math.PI / 2;
      const speed = 4 + Math.random() * 9;
      const isPetal = Math.random() > 0.45;

      this.particles.push({
        x: x,
        y: y,
        vx: Math.cos(angle) * speed + (Math.random() - 0.5) * 2,
        vy: Math.sin(angle) * speed - 2,
        gravity: 0.18 + Math.random() * 0.12,
        wobble: Math.random() * Math.PI * 2,
        wobbleSpeed: 0.04 + Math.random() * 0.06,
        size: isPetal ? (7 + Math.random() * 6) : (5 + Math.random() * 5),
        color: this.colors[Math.floor(Math.random() * this.colors.length)],
        rotation: Math.random() * Math.PI * 2,
        rotationSpeed: (Math.random() - 0.5) * 0.1,
        isPetal: isPetal,
        alpha: 1,
        decay: 0.005 + Math.random() * 0.008
      });
    }

    if (!this.animating) {
      this.animating = true;
      this.loop();
    }
  }

  loop() {
    this.ctx.clearRect(0, 0, this.width, this.height);

    for (let i = this.particles.length - 1; i >= 0; i--) {
      const p = this.particles[i];
      p.x += p.vx + Math.sin(p.wobble) * 1.5;
      p.y += p.vy;
      p.vy += p.gravity;
      p.wobble += p.wobbleSpeed;
      p.rotation += p.rotationSpeed;
      p.alpha -= p.decay;

      if (p.alpha <= 0 || p.y > this.height + 20) {
        this.particles.splice(i, 1);
        continue;
      }

      this.ctx.save();
      this.ctx.translate(p.x, p.y);
      this.ctx.rotate(p.rotation);
      this.ctx.globalAlpha = Math.max(0, p.alpha);
      this.ctx.fillStyle = p.color;

      if (p.isPetal) {
        // Draw organic curved flower petal
        this.ctx.beginPath();
        this.ctx.ellipse(0, 0, p.size * 0.6, p.size, Math.PI / 4, 0, Math.PI * 2);
        this.ctx.fill();
      } else {
        // Draw metallic gold foil ribbon/square
        this.ctx.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.7);
      }

      this.ctx.restore();
    }

    if (this.particles.length > 0) {
      requestAnimationFrame(() => this.loop());
    } else {
      this.animating = false;
      this.ctx.clearRect(0, 0, this.width, this.height);
    }
  }
}

// ==========================================================================
// 12. DUA WALL & SHOWER BLESSINGS CONTROLLER
// ==========================================================================
class BlessingsWallController {
  constructor(confettiEngine) {
    this.confettiEngine = confettiEngine;
    this.duaChips = document.querySelectorAll('.dua-chip-btn');
    this.showerBtn = document.getElementById('btn-shower-petals');
    this.counterElem = document.getElementById('blessing-counter');
    this.toastElem = document.getElementById('toast-copied');

    this.blessingCount = parseInt(localStorage.getItem('wedding_blessing_count') || '128', 10);
    this.updateCounterUI();
    this.init();
  }

  init() {
    this.duaChips.forEach(chip => {
      chip.addEventListener('click', (e) => {
        const text = chip.getAttribute('data-dua-text');
        this.handleDuaClick(chip, text, e);
      });
    });

    if (this.showerBtn) {
      this.showerBtn.addEventListener('click', () => this.handleShowerAll());
    }
  }

  handleDuaClick(chip, text, event) {
    // Add active feedback
    chip.classList.add('dua-active');
    setTimeout(() => chip.classList.remove('dua-active'), 600);

    // Particle burst originating at chip position
    if (this.confettiEngine) {
      const rect = chip.getBoundingClientRect();
      this.confettiEngine.burst({
        x: rect.left + rect.width / 2,
        y: rect.top + rect.height / 2,
        count: 28,
        spread: 120
      });
    }

    // Increment count
    this.blessingCount++;
    localStorage.setItem('wedding_blessing_count', String(this.blessingCount));
    this.updateCounterUI();

    // Show toast
    this.showToast(text || 'Dua and blessings sent with heartfelt love!');
  }

  handleShowerAll() {
    if (this.confettiEngine) {
      this.confettiEngine.fireCelebration();
    }

    this.blessingCount += 5;
    localStorage.setItem('wedding_blessing_count', String(this.blessingCount));
    this.updateCounterUI();

    this.showToast('Alhamdulillah! Golden petals and prayers showered upon Thaiyeba &amp; Irshath ✨');
  }

  updateCounterUI() {
    if (this.counterElem) {
      this.counterElem.textContent = `${this.blessingCount.toLocaleString()} Blessings Sent`;
    }
  }

  showToast(message) {
    if (!this.toastElem) return;

    const span = this.toastElem.querySelector('span');
    if (span) span.innerHTML = message;

    this.toastElem.classList.add('is-visible');
    clearTimeout(this.toastTimeout);
    this.toastTimeout = setTimeout(() => {
      this.toastElem.classList.remove('is-visible');
    }, 3800);
  }
}

// ==========================================================================
// 13. INITIALIZATION ENTRY POINT
// ==========================================================================
document.addEventListener('DOMContentLoaded', () => {
  // 1. Audio Experience
  const audio = new LuxuryAudioExperience();

  // 2. Confetti & Petals Engine
  const confetti = new ConfettiAndPetalBurst();
  window.confettiBurst = confetti;

  // 3. Opening Envelope Experience (with confetti celebration)
  new EnvelopeOpeningController(audio, confetti);

  // 4. Live Countdown
  new WeddingCountdown();

  // 5. Interactive Venue Switcher (Karaikudi / Thanjavur)
  new VenueSwitcherController();

  // 6. Calendar Integration (Save Dates & Dual .ICS)
  new CalendarIntegration();

  // 7. Social Sharing & QR
  new SharingExperience();

  // 8. Luxury Ambient Particle Canvas
  new AmbientCanvasParticles();

  // 9. 3D Card Perspective Tilt
  new CardTiltController();

  // 10. Interactive Dua Wall & Shower Blessings
  new BlessingsWallController(confetti);

  // 11. Navigation & Scroll Controller
  new NavigationAndScrollController();
});
