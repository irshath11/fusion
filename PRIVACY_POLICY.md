# Privacy Policy — Fusion 360 Workforce Manager

**Last Updated: August 24, 2026**

**Fusion 360 Workforce Manager** we operates the **Fusion 360** mobile application. This page informs users of our policies regarding the collection, use, and disclosure of Personal Information when using our Service.

---

## 1. Information Collection and Use

For a seamless attendance verification and field workforce management experience, our application requests access to the following personal and device data:

### A. Location Data (GPS)
- **Purpose**: Precise GPS coordinates (latitude, longitude, and accuracy) are requested during check-in, site visits, and check-out events to validate employee presence within designated organization geofence perimeters.
- **Scope**: Location data is retrieved only when an active check-in or duty action is performed by the user. Continuous background tracking is restricted to active duty status.

### B. Camera & Photos
- **Purpose**: Live selfie photos are captured during office and site check-in/check-out events to verify employee identity.
- **Storage**: Photos are compressed locally on the device (480px JPEG format) and securely transmitted to encrypted cloud storage.

### C. Device Identification & Hardware Fingerprinting
- **Purpose**: Device hardware identifiers (device model, operating system version, and unique hardware binding keys) are recorded to prevent unauthorized buddy punching and enforce hardware device binding policies.

### D. User Account Information
- **Purpose**: User full name, enterprise email address, user role (`SUPER_ADMIN`, `ADMIN`, `EMPLOYEE`), and office assignment details are stored for role-based access control (RBAC).

---

## 2. Data Storage & Security

- **Offline Storage**: Attendance records and device fingerprints are stored locally using encrypted key-value boxes (`Hive`).
- **Cloud Infrastructure**: Cloud data synchronization is transmitted over secure TLS/HTTPS connections to enterprise database services (`Supabase` & `Firebase`).
- **Access Control**: Database tables enforce strict Row-Level Security (RLS) policies ensuring data is accessible only by authorized organization administrators.

---

## 3. Data Retention & Deletion

- Attendance records and verification photos are retained for as long as your employer or organization maintains an active enterprise subscription.
- Users may request account deletion or data removal by contacting their organization Administrator or writing to our privacy support team.

---

## 4. Third-Party Services

Our application integrates with the following third-party infrastructure providers:
- **Firebase Authentication** (Identity management)
- **Supabase Cloud PostgreSQL** (Database & Storage)
- **OpenStreetMap** (Map & Geofence visualization)

---

## 5. Contact Us

If you have any questions or concerns regarding this Privacy Policy, please contact us at:
- **Email**: sr.irshath@gmail.com
- **Website**: https://github.com/irshath11/fusion
