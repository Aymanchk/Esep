from django.test import TestCase
from django.contrib.auth import get_user_model
from api.models import Debt
from api.views import recalculate_and_simplify_debts

User = get_user_model()

class DebtSimplificationTest(TestCase):
    def setUp(self):
        # Create users
        self.user1 = User.objects.create_user(
            username="user1@example.com",
            email="user1@example.com",
            password="password123",
            first_name="User1"
        )
        self.user2 = User.objects.create_user(
            username="user2@example.com",
            email="user2@example.com",
            password="password123",
            first_name="User2"
        )
        self.user3 = User.objects.create_user(
            username="user3@example.com",
            email="user3@example.com",
            password="password123",
            first_name="User3"
        )

    def test_simplification_three_users_chain(self):
        """
        Test that a chain of debts (User 1 -> User 2 -> User 3) is simplified to (User 1 -> User 3).
        """
        # Create debts: User 1 owes User 2 100 som, User 2 owes User 3 100 som.
        Debt.objects.create(
            from_user=self.user1,
            to_user=self.user2,
            amount=100.00,
            description="Chain part 1"
        )
        Debt.objects.create(
            from_user=self.user2,
            to_user=self.user3,
            amount=100.00,
            description="Chain part 2"
        )

        # Before simplification
        self.assertEqual(Debt.objects.filter(is_paid=False).count(), 2)

        # Simplify
        recalculate_and_simplify_debts()

        # After simplification
        active_debts = Debt.objects.filter(is_paid=False)
        self.assertEqual(active_debts.count(), 1)
        
        debt = active_debts.first()
        self.assertEqual(debt.from_user, self.user1)
        self.assertEqual(debt.to_user, self.user3)
        self.assertEqual(float(debt.amount), 100.00)


from django.urls import reverse
from api.models import PhoneOTP

class AuthenticationTest(TestCase):
    def test_send_otp_success(self):
        url = reverse("send-otp")
        response = self.client.post(url, {"phone": "+996777111222"}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["success"])
        
        # Verify saved OTP
        otp = PhoneOTP.objects.get(phone="+996777111222")
        self.assertEqual(len(otp.code), 6)

    def test_verify_otp_success(self):
        # Setup OTP
        phone = "+996777111222"
        code = "987654"
        PhoneOTP.objects.create(phone=phone, code=code)
        
        url = reverse("verify-otp")
        response = self.client.post(url, {"phone": phone, "code": code}, content_type="application/json")
        self.assertEqual(response.status_code, 200)
        
        data = response.json()
        self.assertIn("token", data)
        self.assertIn("user", data)
        self.assertEqual(data["user"]["phone"], phone)
        
        # Verify user was created
        user = User.objects.get(phone=phone)
        self.assertEqual(user.username, "phone_996777111222")

    def test_telegram_auth_debug_bypass(self):
        # We test debug bypass of signature verification
        url = reverse("telegram-auth")
        
        # Mock initData query string with user JSON
        init_data = "user=%7B%22id%22%3A12345%2C%22first_name%22%3A%22Test%22%2C%22username%22%3A%22test_tg%22%7D&hash=mockhash"
        
        # Ensure DEBUG is True
        with self.settings(DEBUG=True, TELEGRAM_BOT_TOKEN=""):
            response = self.client.post(url, {"initData": init_data}, content_type="application/json")
            self.assertEqual(response.status_code, 200)
            
            data = response.json()
            self.assertIn("token", data)
            self.assertEqual(data["user"]["name"], "Test")
            
            # Verify user exists
            user = User.objects.get(telegram_id="12345")
            self.assertEqual(user.username, "test_tg")


from unittest.mock import patch

class BillNotificationTest(TestCase):
    def setUp(self):
        self.creator = User.objects.create_user(
            username="creator@example.com",
            email="creator@example.com",
            password="password123",
            first_name="Creator"
        )
        self.participant = User.objects.create_user(
            username="participant@example.com",
            email="participant@example.com",
            password="password123",
            first_name="Participant",
            telegram_id="999888777"
        )
        from rest_framework_simplejwt.tokens import RefreshToken
        token = RefreshToken.for_user(self.creator).access_token
        self.client.defaults['HTTP_AUTHORIZATION'] = f'Bearer {token}'

    @patch("api.views.send_telegram_message_async")
    def test_bill_creation_triggers_telegram_notification(self, mock_send):
        url = reverse("bill-list")
        payload = {
            "total": 1500.00,
            "title": "Ужин в чайхане",
            "people": [
                {"name": "Creator", "id": "creator_id", "userId": self.creator.id},
                {"name": "Participant", "id": "part_id", "userId": self.participant.id}
            ],
            "debts": [
                {
                    "from_user_id": self.participant.id,
                    "to_user_id": self.creator.id,
                    "amount": 750.00,
                    "description": "Ужин в чайхане"
                }
            ],
            "items": [],
            "assignments": {},
            "category": "food",
            "currency": "KGS"
        }
        
        response = self.client.post(url, payload, content_type="application/json")
        self.assertEqual(response.status_code, 201)
        
        # Verify that send_telegram_message_async was called once for the participant
        mock_send.assert_called_once()
        args, kwargs = mock_send.call_args
        self.assertEqual(args[0], "999888777")  # chat_id
        self.assertIn("Creator", args[1])        # Creator's name
        self.assertIn("Ужин в чайхане", args[1]) # Bill title
