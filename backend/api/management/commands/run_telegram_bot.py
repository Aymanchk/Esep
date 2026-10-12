import sys
import time
import requests
from django.core.management.base import BaseCommand
from django.conf import settings

class Command(BaseCommand):
    help = "Runs a simple polling Telegram bot to open the FairSplitter WebApp"

    def add_arguments(self, parser):
        parser.add_argument(
            "--url",
            type=str,
            default="http://localhost:8080/",
            help="The URL of the WebApp to open (e.g., http://localhost:8080/ or your deployed domain)",
        )

    def handle(self, *args, **options):
        bot_token = getattr(settings, "TELEGRAM_BOT_TOKEN", "")
        if not bot_token:
            self.stderr.write("Error: TELEGRAM_BOT_TOKEN is not defined in settings.py")
            sys.exit(1)

        webapp_url = options["url"]
        self.stdout.write(self.style.SUCCESS(f"Starting Telegram bot..."))
        self.stdout.write(f"WebApp URL: {webapp_url}")
        self.stdout.write("Send /start to your bot in Telegram to get the Mini App button.")

        base_url = f"https://api.telegram.org/bot{bot_token}"
        offset = 0

        while True:
            try:
                # Poll for updates
                resp = requests.get(f"{base_url}/getUpdates", params={"offset": offset, "timeout": 20}, timeout=25)
                if resp.status_code != 200:
                    self.stderr.write(f"Error from Telegram API: {resp.text}")
                    time.sleep(5)
                    continue

                data = resp.json()
                updates = data.get("result", [])
                for update in updates:
                    offset = update["update_id"] + 1
                    message = update.get("message")
                    if not message:
                        continue

                    chat_id = message["chat"]["id"]
                    text = message.get("text", "")
                    user = message.get("from", {})
                    first_name = user.get("first_name", "User")

                    self.stdout.write(f"Received message: '{text}' from {first_name} ({chat_id})")

                    # Send welcome message with WebApp button
                    keyboard = {
                        "inline_keyboard": [
                            [
                                {
                                    "text": "Открыть FairSplitter",
                                    "web_app": {"url": webapp_url}
                                }
                            ]
                        ]
                    }

                    welcome_text = (
                        f"Привет, {first_name}!\n\n"
                        f"Добро пожаловать в FairSplitter — приложение для честного разделения совместных счетов с ИИ и минимизацией долгов.\n\n"
                        f"Нажмите на кнопку ниже, чтобы открыть приложение прямо в Telegram!"
                    )

                    payload = {
                        "chat_id": chat_id,
                        "text": welcome_text,
                        "reply_markup": keyboard
                    }

                    send_resp = requests.post(f"{base_url}/sendMessage", json=payload)
                    if send_resp.status_code == 200:
                        self.stdout.write(self.style.SUCCESS(f"Sent Mini App button to {first_name}"))
                    else:
                        self.stderr.write(f"Failed to send message: {send_resp.text}")

            except KeyboardInterrupt:
                self.stdout.write("\nStopping Telegram bot...")
                break
            except Exception as e:
                self.stderr.write(f"Exception in polling loop: {e}")
                time.sleep(5)
