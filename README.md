<div align="center">

# Fair Splitter

**Делите  честно — Split bills fairly**

A modern bill-splitting app with OCR receipt scanning, real-time calculations, and social sharing.

Built with **Flutter** + **Django REST Framework**

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Django](https://img.shields.io/badge/Django-092E20?style=for-the-badge&logo=django&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-000000?style=for-the-badge&logo=jsonwebtokens&logoColor=white)

</div>

---

## Features

- **Receipt OCR Scanning** — photograph a bill and auto-extract items & prices via Google ML Kit
- **Smart Splitting** — assign items to people with drag-and-drop, support for shared dishes
- **Service Charge** — apply 0%, 10%, or 15% tip, distributed proportionally
- **Social Sharing** — send the breakdown via Telegram, WhatsApp, or system share
- **User Accounts** — register, login, or continue as guest
- **Bill History** — save and review past splits (for registered users)
- **Dark UI** — sleek dark theme with purple accents, Material 3

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter, Provider, Google ML Kit |
| Backend | Django, Django REST Framework |
| Auth | JWT (SimpleJWT) |
| Database | PostgreSQL |
| OCR | Google ML Kit Text Recognition |

## Project Structure

```
FairSplitter/
├── lib/
│   ├── models/          # BillItem, Person
│   ├── providers/       # BillProvider, AuthProvider
│   ├── screens/         # Register, Login, AddPeople, Split, Summary
│   ├── services/        # API client
│   ├── utils/           # OCR helper, Share helper
│   └── theme/           # Dark theme config
│
├── backend/
│   ├── api/             # Models, Views, Serializers, URLs
│   ├── backend/         # Django settings
│   └── requirements.txt
```

## Getting Started

### Prerequisites

- Flutter SDK 3.x
- Python 3.10+
- PostgreSQL

### Backend Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Frontend Setup

```bash
flutter pub get
flutter run
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register/` | Register new user |
| POST | `/api/auth/login/` | Login & get JWT tokens |
| GET | `/api/auth/me/` | Get current user profile |
| GET | `/api/bills/` | List user's bills |
| POST | `/api/bills/` | Save a bill |
| GET | `/api/bills/<id>/` | Get bill details |
| DELETE | `/api/bills/<id>/` | Delete a bill |

## How It Works

1. **Add people** — enter names of everyone splitting the bill
2. **Add items** — manually type or scan the receipt with your camera
3. **Assign items** — drag each dish to the person who ordered it (or share between multiple people)
4. **View summary** — see the breakdown with service charge applied
5. **Share** — send results to Telegram, WhatsApp, or any app

