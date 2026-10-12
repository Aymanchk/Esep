<div align="center">

# Esep

**Split bills fairly — scan a receipt, assign dishes, settle up.**

Built with **Flutter** + **Django REST Framework**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Django](https://img.shields.io/badge/Django-092E20?style=for-the-badge&logo=django&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white)

<!-- TODO: add screenshot — onboarding screen -->
<!-- TODO: add screenshot — split screen with items assigned to people -->
<!-- TODO: add screenshot — summary/breakdown screen -->

</div>

---

## What is Esep?

Splitting a restaurant bill by hand is tedious and error-prone: someone has to retype every line, figure out who shared what, and apply the service charge correctly. Esep automates that: photograph the receipt, let AI (or on-device OCR) read out the line items, drag each item onto the people who ordered it, and get an itemized per-person total — including a configurable service charge — ready to share.

## Features

- **Receipt OCR scanning** — photograph a receipt; items and prices are extracted automatically
- **Flexible splitting** — split by item (with shared dishes), equally, by percentage, or by shares
- **Service charge** — a configurable percentage, with per-category defaults (e.g. restaurants default to 10%)
- **Social sharing** — send the breakdown as an image or text via Telegram, WhatsApp, or the system share sheet
- **Accounts & guest mode** — register/login with phone OTP or Telegram Mini App auth, or just continue as a guest
- **Friend groups, debts & notifications** — save bills, track who owes whom, get notified
- **Telegram Mini App support** — can run embedded inside Telegram

## How it works

```
 ┌──────────────┐     ┌────────────────────┐     ┌──────────────────┐     ┌─────────────┐
 │  Scan receipt │ --> │  OCR extraction    │ --> │  Assign items     │ --> │   Summary   │
 │ (camera/      │     │  Gemini 1.5 Flash  │     │  to people        │     │  per-person │
 │  gallery)     │     │  (server) or       │     │  (shared dishes   │     │   totals +  │
 │               │     │  on-device ML Kit  │     │   supported)      │     │   service   │
 │               │     │  fallback          │     │                   │     │   charge    │
 └──────────────┘     └────────────────────┘     └──────────────────┘     └─────────────┘
```

If a backend/Gemini call isn't available or fails, the app falls back to on-device text recognition (Google ML Kit) and a set of regex-based receipt parsing strategies (see [`lib/utils/ocr_helper.dart`](lib/utils/ocr_helper.dart)). Money is modeled per bill item (price × quantity), and each person's share is computed by `BillProvider` ([`lib/providers/bill_provider.dart`](lib/providers/bill_provider.dart)) depending on the chosen split mode:

- **By items** — a person pays for the units assigned to them; an item shared by more people than its quantity is divided proportionally across every claimed share
- **Equal** — the subtotal is divided evenly across everyone
- **Percentage** — each person pays their assigned percentage of the subtotal
- **Shares** — the subtotal is divided proportionally to each person's share count

> **Known limitation:** nothing currently validates that percentages sum to 100%, or that every item has been assigned to someone — see [`test/bill_provider_test.dart`](test/bill_provider_test.dart) for tests that document exactly when the sum of per-person totals can fall short of the bill total.

## Tech stack & architecture

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter, Provider (state management), Google ML Kit (on-device OCR) |
| Backend | Django, Django REST Framework |
| Auth | JWT (SimpleJWT), phone OTP, Telegram Mini App auth |
| Database | PostgreSQL (SQLite for tests) |
| AI OCR | Google Gemini 1.5 Flash (server-side, optional) |

The Flutter app uses `provider` for state (`BillProvider`, `AuthProvider`, `DebtProvider`, `GroupProvider`, `NotificationProvider`, wired up in [`lib/main.dart`](lib/main.dart)) and a bottom-nav `IndexedStack` shell ([`lib/screens/home_shell.dart`](lib/screens/home_shell.dart)) for the four main tabs; everything else is pushed with standard `Navigator` routes. The backend is a fairly conventional Django REST Framework app — function-based views in [`backend/api/views.py`](backend/api/views.py), JWT auth, and a `channels`/`daphne` ASGI setup currently unused after the chat feature was removed.

## Getting started

### Prerequisites

- Flutter SDK (see `environment.sdk` in [`pubspec.yaml`](pubspec.yaml))
- Python 3.10+
- PostgreSQL (or just use SQLite locally — see below)

### Backend setup

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then fill in the values below
python manage.py migrate
python manage.py runserver
```

Environment variables (see [`backend/.env.example`](backend/.env.example)):

| Variable | Required? | Where to get it |
|---|---|---|
| `SECRET_KEY` | Yes for production | Generate any random string (e.g. `python -c "import secrets; print(secrets.token_urlsafe(50))"`) |
| `DEBUG` | No (defaults `False`) | `True` for local development only — never in production |
| `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`, `DB_PORT` | Yes, unless running tests (tests use SQLite automatically) | Your local/production PostgreSQL instance |
| `GEMINI_API_KEY` | Only for server-side AI OCR | [Google AI Studio](https://aistudio.google.com/apikey) — without it, OCR still works via on-device ML Kit |
| `TELEGRAM_BOT_TOKEN` | Only for Telegram login / Mini App | [@BotFather](https://t.me/BotFather) on Telegram |
| `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS` | Yes for production | Your deployed domain(s) |

For Android release signing, copy [`android/key.properties.example`](android/key.properties.example) to `android/key.properties` and fill in your own keystore details — see [Flutter's signing guide](https://docs.flutter.dev/deployment/android#signing-the-app).

### Frontend setup

```bash
flutter pub get
flutter run
```

## Running tests

```bash
# Flutter
flutter analyze
flutter test

# Backend (from backend/, with the venv above activated)
python manage.py test
```

CI runs `flutter pub get`, `flutter analyze`, and `flutter test` on every push/PR — see [`.github/workflows/flutter-ci.yml`](.github/workflows/flutter-ci.yml).

## Project structure

```
.
├── lib/
│   ├── models/          # BillItem, Person, ExpenseCategory
│   ├── providers/       # BillProvider, AuthProvider, DebtProvider, GroupProvider, NotificationProvider
│   ├── screens/         # Onboarding, Login/Register, Split, Summary, History, Debts, Groups, Profile, Stats...
│   ├── services/        # ApiService (HTTP client)
│   ├── utils/           # OCR helper, share helper, Telegram Mini App helper
│   └── theme/           # Dark theme config
│
├── backend/
│   ├── api/             # Models, views, serializers, urls, ocr_service.py (Gemini integration)
│   ├── backend/         # Django settings
│   └── requirements.txt
│
└── test/                # Flutter unit tests (money/split-calculation logic) + a smoke widget test
```

## Selected API endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register/` | Register with email/password |
| POST | `/api/auth/login/` | Login & get JWT tokens |
| POST | `/api/auth/otp/send/` | Request a phone OTP code |
| POST | `/api/auth/otp/verify/` | Verify OTP, get JWT tokens |
| POST | `/api/auth/telegram/` | Telegram Mini App login |
| GET/POST | `/api/bills/` | List / save bills |
| GET | `/api/debts/summary/` | Net balances between friends |
| GET/POST | `/api/groups/` | Friend groups |
| POST | `/api/ocr/scan/` | AI receipt scan (Gemini) |

## Known limitations & plans

- Percentage-mode splits don't validate that percentages add up to 100% (see "How it works" above)
- No localization — all UI strings are hardcoded in Russian; no accessibility `Semantics` annotations yet
- `cupertino_icons` and `web_socket_channel` are currently unused dependencies (left over from the removed real-time chat feature) and are candidates for removal
- No crash reporting / structured logging is wired up yet
- App icon and splash screen are still the default Flutter template assets

## License

MIT — see [`LICENSE`](LICENSE).
