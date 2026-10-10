# 🤖💰 Smart Personal Accountant AI App — المحاسب الذكي

<p align="center">
  <img src="assets/images/app_icon.png" width="120" alt="App Icon"/>
</p>

> **محاسبك الشخصي الذكي في جيبك** — A production-ready, 100% Arabic (RTL), offline-first personal finance manager for Android with a real AI accountant powered by **claude-opus-5.5 via the CodeCraft API**.

[![Build APK](https://github.com/ebra7im-coder/Smart-Personal-Accountant-AI-App/actions/workflows/build-apk.yml/badge.svg)](https://github.com/ebra7im-coder/Smart-Personal-Accountant-AI-App/actions/workflows/build-apk.yml)

---

## ✨ Features (MVP — all included)

| # | Feature | Details |
|---|---------|---------|
| 1 | **Onboarding & Auth** | Splash, Login/Register, Google / Apple / Phone-OTP / Guest, 3-page onboarding |
| 2 | **Dashboard** | Total balance, income vs expense, monthly `fl_chart` bar chart, recent transactions |
| 3 | **Add Transaction < 3 clicks** | FAB → speak → AI pre-fills → save. Or + → amount → category chip → save |
| 4 | **AI Voice Input** | `speech_to_text` → Arabic transcript → **claude-opus-5.5** extracts `{amount, category, type, date, note}` → auto-filled sheet |
| 5 | **AI Auto-Categorization** | Every manual note is auto-categorized by the AI into 10 Arabic-aware categories |
| 6 | **AI Chat Accountant** | Full chat screen — Egyptian-persona AI answers with the user's *real* transaction summary injected into the system prompt |
| 7 | **Budget Management** | Monthly per-category budgets, animated progress, **80% & 100% local notifications** |
| 8 | **OCR Receipt Scanner (PRO)** | `google_mlkit_text_recognition` (on-device, offline) → AI parses the receipt into a transaction |
| 9 | **Offline Mode** | Everything is written to **encrypted Hive** first and synced to Firestore when online |
| 10 | **Security** | `local_auth` biometric app-lock + AES-256 encrypted Hive box (key in Android Keystore) |
| 11 | **Reports** | Daily / Weekly / Monthly / Yearly + **PDF (Arabic RTL)** & **Excel** export |

### 💎 Monetization (Freemium)
- **Free**: 70 transactions/month, 15 AI chats/day, banner + interstitial ads, basic reports
- **PRO** (`in_app_purchase`): unlimited AI, OCR, export, no ads
  - Monthly: **15 SAR** (`pro_monthly`)
  - Yearly: **120 SAR** (`pro_yearly`)

---

## 📸 Screenshots

| Dashboard | AI Chat | Voice Input | Paywall |
|:---:|:---:|:---:|:---:|
| ![Dashboard](assets/images/screenshot_placeholder_1.png) | ![Chat](assets/images/screenshot_placeholder_1.png) | ![Voice](assets/images/screenshot_placeholder_1.png) | ![Paywall](assets/images/screenshot_placeholder_1.png) |

*(replace with real screenshots before publishing)*

---

## 🛠 Tech Stack

- **Flutter 3.22.0** (stable) • Dart 3.x • Null safety
- **State management**: Riverpod 2
- **Local DB**: Hive (AES-256 encrypted box; key in secure storage/Keystore)
- **Cloud**: Firebase Auth (Email/Google/Apple/Phone/Guest) • Firestore • FCM
- **Charts**: fl_chart
- **AI**: CodeCraft API → `https://codecraftapi.com/v1/chat/completions` → model `claude-opus-5.5`
- **Voice**: speech_to_text • **OCR**: google_mlkit_text_recognition
- **Security**: local_auth + flutter_secure_storage + encrypt
- **Exports**: pdf (embedded Tajawal font, RTL) + excel
- **Monetization**: in_app_purchase + google_mobile_ads
- **Fonts**: Cairo & Tajawal (bundled — also used inside generated PDFs)

## 🎨 Design System

| Token | Value |
|---|---|
| Royal Blue | `#0F2A54` |
| Money Green | `#00C896` |
| White | `#FFFFFF` |
| Light Grey | `#F5F7FB` |
| Material 3 | ✓ • 100% RTL Arabic UI • Cairo/Tajawal |

---

## 🚀 Getting Started

### 0. Prerequisites
- Flutter **3.22.0** (`flutter --version`)
- Android SDK 34, Java 17

### 1. Configure the AI key (CodeCraft API)

**Never commit the key.** Choose one:

```bash
# A) dart-define (recommended)
flutter run --dart-define=CODECRAFT_API_KEY=YOUR_NEW_cc_KEY_HERE

# B) .env file via dart-define-from-file (works for CI too)
cp .env.example .env      # put your real key inside
flutter run --dart-define-from-file=.env
```

`.env` is already in `.gitignore`. The key is read **only** through
`const String.fromEnvironment('CODECRAFT_API_KEY')` inside `lib/services/ai_service.dart`
(+ secure-storage/injection fallbacks for testing).

### 2. Configure Firebase (optional — app runs fully offline without it)

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an **Android app** with package `com.smartaccountant.ai`, add your SHA-1/SHA-256 (required for Google Sign-In)
3. Enable: **Email/Password**, **Google**, **Apple**, **Anonymous**, **Phone** providers
4. Download `google-services.json` → `android/app/google-services.json`
5. Paste your project's values into `lib/firebase_options.dart` (or run `flutterfire configure`)
6. Create Firestore → use the secure rules in [`firestore.rules`](firestore.rules)
7. (Play Store) Enable Play Billing and create the products `pro_monthly` / `pro_yearly`

> Without Firebase config the app automatically runs in **local-only mode**: Hive still works, AI still works, sync/auth are simply skipped — no crashes.

### 3. Run

```bash
flutter pub get
flutter run --dart-define=CODECRAFT_API_KEY=YOUR_KEY
```

### 4. Release APK

```bash
flutter build apk --release \
  --dart-define=CODECRAFT_API_KEY=YOUR_KEY
# → build/app/outputs/flutter-apk/app-release.apk
```

Or just **push to `main`** — the GitHub Action builds and publishes the APK automatically (see below).

### 5. Production signing (optional, for Play Store upload)

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (git-ignored):

```properties
storePassword=***
keyPassword=***
keyAlias=upload
storeFile=upload-keystore.jks
```

`*.jks` / `*.keystore` / `key.properties` are all git-ignored — **never commit them**.

---

## 🤖 CI/CD — Automated APK on every push

`.github/workflows/build-apk.yml` builds a release APK on every push/PR to `main`/`master`:

1. Add your key: **Repo → Settings → Secrets and variables → Actions → New secret**
   - Name: `CODECRAFT_API_KEY`
2. Push to `main` → the workflow uploads `smart-accountant-apk` artifact and creates a GitHub Release `v1.0.<run_number>` with the APK.

---

## 📁 Project Structure

```
lib/
├── main.dart                  # bootstrap: Hive, Firebase, Ads, routes
├── app.dart                   # MaterialApp, Material-3 theme, RTL
├── app_localizations.dart     # Arabic localization delegate
├── firebase_options.dart      # Firebase config (defensive, optional)
├── models/                    # transaction, budget, user, chat (+ .g adapters)
├── screens/
│   ├── splash/ onboarding/    # entry experiences
│   ├── auth/                  # login, register, phone OTP, forgot password
│   ├── dashboard/             # balance, charts, AI tip, recents
│   ├── add_transaction/       # <3-clicks sheet + voice AI parse
│   ├── ocr/                   # receipt scan confirmation (PRO)
│   ├── budgets/               # budgets + progress + alerts
│   ├── chat/                  # AI accountant chat
│   ├── reports/               # daily/weekly/monthly/yearly + exports
│   ├── transactions/          # searchable list
│   ├── settings/              # security, sync, export, about
│   └── paywall/               # PRO subscriptions (IAP)
├── widgets/                   # custom_button, transaction_card, charts…
├── services/
│   ├── ai_service.dart        # ★ CodeCraft API / claude-opus-5.5
│   ├── hive_service.dart      # ★ encrypted offline-first DB
│   ├── firebase_service.dart  # auth + firestore + fcm
│   ├── sync_service.dart      # offline→cloud sync engine
│   ├── ocr_service.dart       # ML Kit + AI parsing
│   ├── export_service.dart    # Arabic PDF + Excel
│   ├── billing_service.dart   # Play subscriptions
│   ├── ads_service.dart       # AdMob (free plan)
│   ├── notification_service.dart # budget alerts (local + FCM)
│   └── security_service.dart  # biometric lock
├── providers/                 # Riverpod providers
├── utils/                     # constants, helpers, validators
└── l10n/                      # ar.arb + ar.json
```

---

## 🔐 Security & Privacy Checklist

- ✅ `CODECRAFT_API_KEY` only via `--dart-define` / `.env` (git-ignored) — **never hardcoded**
- ✅ Financial data stored in an **AES-256 encrypted Hive box**; key in Android Keystore
- ✅ **Biometric app lock** (with PIN fallback) via `local_auth`
- ✅ Firestore rules lock every document to its owner: `request.auth.uid == uid`
- ✅ Test AdMob IDs by default; swap before release
- ✅ No analytics/tracking beyond Firebase/AdMob defaults

## 🧪 Tests

```bash
flutter test
```

Covers: AI JSON extraction (fenced/prose), CodeCraft request shape (model, Bearer header), voice-parse mapping, aggregation helpers, widget smoke tests.

## 📱 Device Compatibility (متوافق مع جميع الهواتف)

| | |
|---|---|
| **نظام أندرويد** | Android 6.0 Marshmallow (API 23) وأحدث — يغطي ~99% من الأجهزة |
| **المعالجات** | ARM64 (الهواتف الحديثة) • ARM32 (الأجهزة الأقدم) • x86_64 (المحاكيات) |
| **الشاشات** | من 4 بوصات إلى التابلت — واجهة متجاوبة RTL بالكامل |
| **بدون كاميرا/بصمة/مايك** | يُثبَّت ويعمل — الميزات الغائبة تُخفى بأمان |

### أي APK أحمّل من الـ Release؟

| الملف | لمن؟ | الحجم تقريباً |
|---|---|---|
| `app-arm64-v8a-release.apk` | **معظم الهواتف الحديثة (2016+)** ✅ | ~45 MB |
| `app-armeabi-v7a-release.apk` | هواتف أقدم (Android 6-8 الاقتصادية) | ~45 MB |
| `app-x86_64-release.apk` | محاكيات الكمبيوتر والتابلت | ~48 MB |
| `app-release.apk` | Universal — يعمل على أي جهاز | ~106 MB |

## 🤖 AI Robustness (ذكاء اصطناعي لا يتعطل)

- **الإدخال الصوتي يعمل دائماً**: لو الـ API غير متاح أو انقطع الإنترنت، يعمل
  `LocalTransactionParser` محلياً (Regex + قاموس كلمات عربي) ويستخرج
  المبلغ/النوع/التصنيف من الجملة بدون نت.
- **التصنيف التلقائي يحترم اختيارك**: لن يعدّل الـ AI تصنيفاً اخترته يدوياً.
- **رسائل الشات الفاشلة قابلة لإعادة المحاولة** بضغطة واحدة على الفقاعة.
- **نصيحة المحاسب** تظهر بحركة shimmer وتختفي بأمان عند غياب المفتاح.

## 🧯 Troubleshooting

| Symptom | Fix |
|---|---|
| `Gradle build daemon disappeared` / OOM on low-RAM machines (<4GB) | Lower the heap: `org.gradle.jvmargs=-Xmx1536m` in `android/gradle.properties`, add `kotlin.compiler.execution.strategy=in-process`, or set `minifyEnabled false` |
| Google Sign-In fails | Add SHA-1/SHA-256 in Firebase console + updated `google-services.json` |
| AI answers "خدمة الـ AI مش مهيأة" | The `CODECRAFT_API_KEY` dart-define was missing at build time |
| Budget notifications don't appear | Grant the notification permission (Android 13+) in system settings |
| Store prices show defaults in the paywall | Create `pro_monthly` / `pro_yearly` in Play Console and activate them |


## 🗺 Roadmap (post-MVP)

- [ ] iOS build + Sign in with Apple hardening
- [ ] Server-side receipt validation for subscriptions
- [ ] Multi-wallet & shared family budgets
- [ ] Recurring transactions & bills reminders
- [ ] Voice output replies (TTS) for the AI accountant

---

<p align="center">صُنع بـ 💚 باستخدام Flutter + CodeCraft AI</p>
