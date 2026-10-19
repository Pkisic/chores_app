# Chores 🧹✨

A modern, shared chore-tracking Flutter application for couples with real-time Firestore synchronization, timer tracking (with app-restart persistence), weekly timetable scheduling, and anonymous invite-code onboarding.

---

## 🎨 Features & Highlights

1. **Anonymous Auth & Household Invite System**
   - Immediate friction-free onboarding via Firebase Anonymous Authentication.
   - Create a household to generate a short, shareable 6-character invite code.
   - Join existing households by entering the invite code.
2. **Chore Management (CRUD)**
   - Create, edit, and delete custom chores.
   - Pick from a curated icon set and vibrant color palette.
   - Set estimated durations in minutes.
3. **Weekly Timetable & Scheduling**
   - Assign chores to specific household members for any days of the week.
   - Toggle weekly recurring assignments vs. single-instance assignments.
   - Interactive weekly view highlighting the current day.
4. **Resilient Timer**
   - Start and stop active timers for any chore.
   - Real-time elapsed time counter with modern tabular typography.
   - **App Kill / Crash Persistence**: Active timer state (start timestamp and log ID) persists in `SharedPreferences` and seamlessly recomputes elapsed time upon relaunch.
5. **History & Time Logs**
   - Completed chore logs automatically sync across both partners.
   - View history grouped by date, showing who completed each chore and how long it took.
6. **Live 2-Person Synchronization**
   - Powered by Firestore streams (`StreamProvider` via Riverpod). Any change made by partner A (adding a chore, completing a timer, updating schedule) streams live to partner B's device.

---

## 🏗️ Project Architecture & Folder Structure

Built using a **Feature-First Architecture** with a clear separation of concerns:

```
lib/
├── app/
│   ├── router.dart             # Named routes navigation
│   └── theme.dart              # Dark-mode-first theme (Outfit font, coral/teal palette)
├── features/
│   ├── chores/                 # Chore CRUD & curated pickers
│   ├── history/                # Completed time logs history view
│   ├── home/                   # Navigation shell & bottom navigation bar
│   ├── onboarding/             # Create/Join household & anonymous auth
│   ├── schedule/               # Weekly timetable & assignment sheet
│   └── timer/                  # Timer page with SharedPreferences persistence
├── models/                     # Data models (Chore, Household, Member, Schedule, TimeLog)
├── providers/                  # Central Riverpod providers (Streams, Auth, State)
├── repositories/               # Repository layer abstracting Firestore calls
├── shared/                     # Shared constants, curated icons, and glassmorphic UI widgets
├── firebase_options.dart       # Firebase credentials configuration
└── main.dart                   # Application entry point
```

### 🧠 State Management & Data Models Choice

- **Riverpod (`flutter_riverpod`)**: Used for all app state and Firestore reactive streams. No `BuildContext`-dependent state is used.
- **Data Models**: Handcrafted `fromJson`/`toJson`/`copyWith` methods are used instead of `freezed` to keep the project lightweight and eliminate build-runner codegen build times and extra boilerplate overhead.

---

## 🚀 Setup & Firebase Configuration Instructions

### Prerequisites & CLI Tools

1. **Flutter SDK**: Ensure Flutter is installed (v3.12+ recommended). Run `flutter doctor` to verify.
2. **Node.js & npm**: Install Node.js (which includes `npm`) from [nodejs.org](https://nodejs.org/). Node is required to run the Firebase CLI tools.
3. **Firebase Tools CLI**: Install the Firebase CLI globally using npm:
   ```bash
   npm install -g firebase-tools
   ```
4. **Authenticate Firebase CLI**: Log in to your Google account linked to Firebase:
   ```bash
   firebase login
   ```
5. **FlutterFire CLI**: Install the FlutterFire CLI globally using Dart:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   *(Ensure Dart's global bin directory is in your shell PATH if needed).*

---

### Step 1: Create & Configure Firebase Console Project

1. Go to the [Firebase Console](https://console.firebase.google.com/) and click **Add project** (e.g., named **Chores**).
2. **Enable Anonymous Authentication**:
   - In the Firebase Console sidebar, go to **Build > Authentication**.
   - Click **Get Started**, then select **Anonymous** under the *Sign-in method* tab.
   - Click **Enable** and save.
3. **Create Cloud Firestore Database**:
   - Go to **Build > Firestore Database**.
   - Click **Create Database** (choose your closest server location).
   - Start in **Test Mode** (or paste the recommended Security Rules below).

---

### Step 2: Generate Local Configuration (`firebase_options.dart`)

Run the FlutterFire configuration command at the root of your project directory:
```bash
flutterfire configure
```
- Select your Firebase project from the interactive terminal menu.
- Choose your target platforms (e.g., Android, iOS, Web).
- This command automatically creates/updates your local `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`.

*(Note: These config files contain your project API keys and are listed in `.gitignore` to keep secrets off public repositories).*

---

### Step 3: Run the Application

```bash
flutter pub get
flutter run
```

---

## 🧪 How to Test Two-Person Real-Time Sync

You can test real-time synchronization between two devices/emulators:

1. **Launch Device / Emulator A**:
   - Open the app. Enter display name "Partner 1" and tap **Create Household**.
   - Note the **Invite Code** displayed in the app header or share dialog (e.g., `X7K2P9`).
2. **Launch Device / Emulator B**:
   - Open the app on the second device/emulator.
   - Enter display name "Partner 2", switch to the **Join Household** tab, and enter the code (`X7K2P9`).
3. **Verify Sync**:
   - Create a chore on Device A — watch it instantly appear on Device B.
   - Assign a chore to Partner 2 in the Schedule tab on Device B — watch it update live on Device A.
   - Start and stop a timer on Device A — watch the completed entry stream directly into the History tab on Device B.

---

## ⚙️ CI/CD (GitHub Actions)

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| `ci.yml` | every PR, push to `main` | `flutter analyze` + `flutter test`; on PRs also builds a debug APK (downloadable from the run's **Artifacts**) |
| `deploy.yml` | push to `main`, manual | builds the web app and deploys it to **https://chores-913d9.web.app**; deploys `firestore.rules` when it changed |
| `release.yml` | tag `v*` (e.g. `git tag v1.0.0 && git push origin v1.0.0`) | builds a release APK and publishes it as a GitHub Release |

**Secrets.** The gitignored Firebase client config is restored in CI from two
repository secrets, `FIREBASE_OPTIONS_DART` and `GOOGLE_SERVICES_JSON`
(base64 of `lib/firebase_options.dart` and `android/app/google-services.json`).
To update them:

```bash
base64 -w0 lib/firebase_options.dart | gh secret set FIREBASE_OPTIONS_DART
base64 -w0 android/app/google-services.json | gh secret set GOOGLE_SERVICES_JSON
```

**Keyless deploys.** `deploy.yml` authenticates to Google Cloud with
Workload Identity Federation: GitHub's short-lived OIDC token is exchanged
for Google credentials. No service-account key exists anywhere. The
identity provider (`github/chores-app`) only trusts `Pkisic/chores_app` on
`refs/heads/main`. It impersonates `github-deployer@chores-913d9.iam.gserviceaccount.com`,
which only has Hosting, Rules, Service Usage Consumer and Firebase Viewer
roles.

Everything runs on free tiers: public-repo GitHub Actions and the Firebase
Spark plan (billing disabled, so nothing can be charged).

---

## 🛡️ Firestore Security Rules (Recommended)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /households/{householdId} {
      allow read, write: if request.auth != null;
      match /{allSubcollections=**} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```
