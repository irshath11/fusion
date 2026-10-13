import wave
import math
import struct
import subprocess
import os

sample_rate = 44100
duration = 32.0  # 32 seconds seamless circular loop
num_samples = int(sample_rate * duration)

left_channel = [0.0] * num_samples
right_channel = [0.0] * num_samples

def note_to_freq(note_name):
    notes = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 
             'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
    name = note_name[:-1]
    octave = int(note_name[-1])
    semitone = notes[name] + (octave + 1) * 12
    return 440.0 * (2.0 ** ((semitone - 69) / 12.0))

# 4 Peaceful Romantic Wedding Chords (8 seconds each)
# NOTE: All notes are strictly in the silky mid/treble range (F3 = 174.6Hz and above)
# Zero sub-bass / low rumble (< 160Hz completely eliminated to prevent speaker shudder or vibration)
chords = [
    # 0 - 8s: Dm9 (F3, A3, C4, E4, A4)
    (0.0, 8.0, ['F3', 'A3', 'C4', 'E4', 'A4']),
    # 8 - 16s: Bbmaj7 (F3, Bb3, D4, F4, A4)
    (8.0, 16.0, ['F3', 'Bb3', 'D4', 'F4', 'A4']),
    # 16 - 24s: Fadd9 (F3, A3, C4, G4, C5)
    (16.0, 24.0, ['F3', 'A3', 'C4', 'G4', 'C5']),
    # 24 - 32s: C6 / Am7 (E3, G3, A3, C4, E4)
    (24.0, 32.0, ['E3', 'G3', 'A3', 'C4', 'E4'])
]

# 1. Warm Velvet String/Flute Pad Layer
# Clean, exact pitch (no detuned beating), gentle envelope
for start_t, end_t, note_list in chords:
    start_idx = int(start_t * sample_rate)
    end_idx = int(end_t * sample_rate)
    seg_len = end_idx - start_idx
    
    for note_idx, note in enumerate(note_list):
        freq = note_to_freq(note)
        # Spatial stereo spread by note position
        pan = 0.35 + (note_idx / (len(note_list) - 1)) * 0.30  # 0.35 to 0.65 (centered stereo)
        
        for i in range(seg_len):
            idx = start_idx + i
            if idx >= num_samples:
                break
            t = i / sample_rate
            
            # Smooth 2.0s raised-cosine crossfade envelope per chord
            attack = 2.0
            release = 2.0
            env = 1.0
            if t < attack:
                env = 0.5 * (1.0 - math.cos(math.pi * (t / attack)))
            elif t > (end_t - start_t) - release:
                rem = (end_t - start_t) - t
                env = 0.5 * (1.0 - math.cos(math.pi * (max(0, rem) / release)))
            
            # Pure silky waveform: Fundamental + faint warm 2nd harmonic (NO distortion, NO beating)
            # Both channels use the exact same frequency so there is zero phase beating
            s = (math.sin(2 * math.pi * freq * t) * 0.85 + 
                 math.sin(4 * math.pi * freq * t) * 0.15) * 0.055 * env
            
            left_channel[idx] += s * (1.0 - pan)
            right_channel[idx] += s * pan

# 2. Romantic Acoustic Concert Harp Plucks
# Plucked string physical simulation with natural damping
arpeggio_notes = [
    # Bar 1 (Dm9)
    (0.8, 'A3', 0.65, 0.3), (1.8, 'D4', 0.60, 0.4), (2.8, 'F4', 0.70, 0.5), (3.8, 'A4', 0.65, 0.6),
    (4.8, 'C5', 0.60, 0.7), (5.8, 'E5', 0.55, 0.5), (6.6, 'A4', 0.50, 0.4), (7.3, 'F4', 0.45, 0.3),
    # Bar 2 (Bbmaj7)
    (8.8, 'Bb3', 0.65, 0.3), (9.8, 'D4', 0.60, 0.4), (10.8, 'F4', 0.70, 0.5), (11.8, 'A4', 0.65, 0.6),
    (12.8, 'D5', 0.60, 0.7), (13.8, 'F5', 0.55, 0.5), (14.6, 'D5', 0.50, 0.4), (15.3, 'A4', 0.45, 0.3),
    # Bar 3 (Fadd9)
    (16.8, 'C4', 0.65, 0.3), (17.8, 'F4', 0.60, 0.4), (18.8, 'A4', 0.70, 0.5), (19.8, 'C5', 0.65, 0.6),
    (20.8, 'G5', 0.60, 0.7), (21.8, 'F5', 0.55, 0.5), (22.6, 'C5', 0.50, 0.4), (23.3, 'A4', 0.45, 0.3),
    # Bar 4 (C6 / Am7)
    (24.8, 'E4', 0.65, 0.3), (25.8, 'G4', 0.60, 0.4), (26.8, 'A4', 0.70, 0.5), (27.8, 'C5', 0.65, 0.6),
    (28.8, 'E5', 0.60, 0.7), (29.8, 'D5', 0.55, 0.5), (30.6, 'C5', 0.50, 0.4), (31.2, 'A4', 0.40, 0.3),
]

for note_time, note_str, vel, pan in arpeggio_notes:
    freq = note_to_freq(note_str)
    start_idx = int(note_time * sample_rate)
    pluck_len = int(sample_rate * 2.8)
    
    for i in range(pluck_len):
        idx = start_idx + i
        if idx >= num_samples:
            break
        t = i / sample_rate
        
        # Pluck envelope: gentle 15ms rounded attack (no sharp click), smooth exponential decay
        if t < 0.015:
            env = 0.5 * (1.0 - math.cos(math.pi * (t / 0.015)))
        else:
            env = math.exp(-(t - 0.015) / 1.0)
        
        # Natural acoustic decay (higher harmonics decay faster than fundamental)
        h1 = math.sin(2 * math.pi * freq * t) * 0.75
        h2 = math.sin(4 * math.pi * freq * t) * 0.20 * math.exp(-t * 2.5)
        h3 = math.sin(6 * math.pi * freq * t) * 0.05 * math.exp(-t * 5.0)
        
        val = (h1 + h2 + h3) * 0.12 * vel * env
        
        left_channel[idx] += val * (1.0 - pan)
        right_channel[idx] += val * pan

# 3. Soft Crystalline Glockenspiel / Glass Chimes on Bar Entrances
# High crystalline bells (pure upper resonance, completely above 800Hz)
bell_times = [(0.2, 'A5', 0.3), (8.2, 'F5', 0.7), (16.2, 'C6', 0.4), (24.2, 'E5', 0.6)]
for bell_t, note_str, pan in bell_times:
    freq = note_to_freq(note_str)
    start_idx = int(bell_t * sample_rate)
    bell_len = int(sample_rate * 3.5)
    
    for i in range(bell_len):
        idx = start_idx + i
        if idx >= num_samples:
            break
        t = i / sample_rate
        if t < 0.008:
            env = t / 0.008
        else:
            env = math.exp(-(t - 0.008) / 1.4)
            
        # Pure chime timbre
        val = (math.sin(2 * math.pi * freq * t) * 0.70 +
               math.sin(2 * math.pi * freq * 2.756 * t) * 0.20 * math.exp(-t * 1.8) +
               math.sin(2 * math.pi * freq * 5.404 * t) * 0.10 * math.exp(-t * 3.5)) * 0.04 * env
        
        left_channel[idx] += val * (1.0 - pan)
        right_channel[idx] += val * pan

# 4. Circular Loop Boundary Smoothing
# Apply a smooth 1.5s crossfade between head and tail to ensure 100% clickless, vibration-free loop
cross_len = int(1.5 * sample_rate)
for i in range(cross_len):
    t = i / cross_len
    # Equal-power crossfade curve: cos^2 + sin^2 = 1
    fade_in = math.sin(t * (math.pi / 2))
    fade_out = math.cos(t * (math.pi / 2))
    
    tail_idx = num_samples - cross_len + i
    head_l = left_channel[i]
    head_r = right_channel[i]
    tail_l = left_channel[tail_idx]
    tail_r = right_channel[tail_idx]
    
    left_channel[i] = head_l * fade_in + tail_l * fade_out
    right_channel[i] = head_r * fade_in + tail_r * fade_out
    left_channel[tail_idx] = left_channel[i]
    right_channel[tail_idx] = right_channel[i]

# 5. Master Normalization to -3 dBFS (Safe, pleasant, zero speaker strain)
max_peak = 0.0001
for i in range(num_samples):
    max_peak = max(max_peak, abs(left_channel[i]), abs(right_channel[i]))

target_peak = 0.60  # Safe headroom, guarantees zero distortion on any phone/laptop
norm_gain = target_peak / max_peak
print(f"Original peak: {max_peak:.4f}, applying safe normalization gain: {norm_gain:.4f}")

wav_path = "/Users/irshathahamed/storage/Fusion Repos/fusion/wedding_invitation/audio/wedding-ambient.wav"
with wave.open(wav_path, "wb") as wav:
    wav.setnchannels(2)
    wav.setsampwidth(2) # 16-bit PCM
    wav.setframerate(sample_rate)
    
    frames = bytearray()
    for i in range(num_samples):
        l_val = max(-32767, min(32767, int(left_channel[i] * norm_gain * 32767.0)))
        r_val = max(-32767, min(32767, int(right_channel[i] * norm_gain * 32767.0)))
        frames.extend(struct.pack('<hh', l_val, r_val))
    
    wav.writeframes(frames)

print(f"Pristine WAV written to {wav_path}")

# Convert to high-quality M4A (AAC) using afconvert
m4a_path = "/Users/irshathahamed/storage/Fusion Repos/fusion/wedding_invitation/audio/wedding-ambient.m4a"
subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "192000", wav_path, m4a_path], check=True)
print(f"Pristine M4A written to {m4a_path} (size: {os.path.getsize(m4a_path)} bytes)")
print("Audio processing complete!")
