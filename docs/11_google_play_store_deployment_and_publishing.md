# Module 11: Google Play Store Deployment & Publishing Infrastructure

## Overview
This module documents the production release pipeline, Android App Bundle (`.aab`) compilation workflow, keystore signing configuration, and Google Play Console compliance setup for **Fusion 360 Workforce Manager**.

---

## 1. Android Keystore Signing Setup

The application uses an enterprise upload keystore (`upload-keystore.jks`) and environment properties (`key.properties`) for cryptographic release signing.

### Cryptographic Configuration Files
- **Keystore File**: [`android/app/upload-keystore.jks`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/android/app/upload-keystore.jks)
- **Properties File**: [`android/key.properties`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/android/key.properties)

### Keystore Configuration Format (`key.properties`)
```properties
storePassword=fusionapp123
keyPassword=fusionapp123
keyAlias=upload
storeFile=upload-keystore.jks
```

### Gradle Build Integration (`android/app/build.gradle.kts`)
```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.fusion.attendance"
    compileSdk = 36
    
    defaultConfig {
        applicationId = "com.fusion.attendance"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (keystorePropertiesFile.exists() && releaseSigning.storeFile != null) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}
```

---

## 2. Release App Bundle Compilation

To build a signed production Android App Bundle (`.aab`):

```bash
# 1. Update build version in pubspec.yaml if uploading a new release (e.g. version: 1.0.0+1 -> version: 1.0.0+2)
# 2. Execute build command
flutter build appbundle --release
```

**Output Artifact Path**:  
`build/app/outputs/bundle/release/app-release.aab`

---

## 3. Google Play Console Compliance Declarations

| Compliance Category | Declaration & Configuration | Details & Rationale |
| :--- | :--- | :--- |
| **Package Name** | `com.fusion.attendance` | Must match `applicationId` in `build.gradle.kts`. |
| **App Access Credentials** | `Yes` (Restricted) | Demo Admin & Employee credentials provided for Google Reviewers to inspect dashboard features. |
| **Content Ratings (IARC)** | `PEGI 3` / `Everyone 3+` | Questionnaire answers: `No` to downloaded rating content, user content sharing, location sharing with strangers, or restricted products. |
| **Data Safety** | `Yes` (Data Collected & Encrypted) | Discloses **Approximate Location**, **Precise Location**, **Name**, and **Email Address** collected for app functionality & account management. Encrypted in transit via TLS/HTTPS. |
| **Account Deletion Link** | [`PRIVACY_POLICY.md`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/PRIVACY_POLICY.md) | Public URL (`https://github.com/irshath11/fusion/blob/main/PRIVACY_POLICY.md`) detailing account and data deletion procedures. |
| **AI Asset Declaration** | `Don't label assets` | Standard UI icons, vector artwork, and screenshots do not require synthetic AI content badges. |

---

## 4. Store Listing Assets & Visual Deliverables

| Asset Type | Specifications | File Location | Description |
| :--- | :--- | :--- | :--- |
| **App Icon** | 512 × 512 px PNG/JPEG | [`app_icon_512.jpg`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/app_icon_512.jpg) | High-res vector launcher icon with location pin, clock face, and emerald checkmark. |
| **Feature Graphic** | 1,024 × 500 px PNG/JPEG (16:9) | [`feature_graphic.jpg`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/feature_graphic.jpg) | Figma-style minimalist SaaS promotional banner showing app branding & mobile screen mockups. |
| **Short Description** | Max 80 Characters | N/A | *"Smart employee attendance tracking with geofence verification and live management."* |
| **Full Description** | Max 4,000 Characters | See `PRIVACY_POLICY.md` & `README.md` | Detailed breakdown of geofenced attendance, selfie photo verification, offline sync, timesheets, & RBAC. |

---

## 5. Release & Testing Tracks

1. **Internal Testing**: Up to 100 internal testers via email list (`Internal Testers`). Rapid distribution for immediate QA verification.
2. **Closed Testing**: Beta testing track with designated tester groups.
3. **Release Promotion**: Tracks can be promoted seamlessly in Play Console without re-uploading identical `.aab` files using **Promote release > Closed testing / Production**.
