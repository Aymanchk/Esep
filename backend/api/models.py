from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    phone = models.CharField(max_length=20, blank=True, null=True)
    avatar = models.ImageField(upload_to='avatars/', blank=True, null=True)

    def __str__(self):
        return self.email or self.username


class ChatRoom(models.Model):
    participants = models.ManyToManyField(User, related_name="chat_rooms")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"ChatRoom #{self.id}"


class Message(models.Model):
    room = models.ForeignKey(ChatRoom, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name="sent_messages")
    text = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"Message #{self.id} from {self.sender}"


class Bill(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="bills")
    total = models.DecimalField(max_digits=10, decimal_places=2)
    service_charge_percent = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    items = models.JSONField(default=list)
    people = models.JSONField(default=list)
    assignments = models.JSONField(default=dict)
    title = models.CharField(max_length=255, blank=True, default="")
    currency = models.CharField(max_length=10, blank=True, default="KGS")
    category = models.CharField(max_length=50, blank=True, default="")
    split_mode = models.CharField(max_length=20, blank=True, default="byItems")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Bill #{self.id} — {self.total} сом ({self.user})"


class Debt(models.Model):
    from_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="debts_owed")
    to_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="debts_received")
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    bill = models.ForeignKey(Bill, on_delete=models.SET_NULL, null=True, blank=True, related_name="debts")
    description = models.CharField(max_length=255, blank=True, default="")
    is_paid = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    paid_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.from_user} -> {self.to_user}: {self.amount} сом"


class FriendGroup(models.Model):
    name = models.CharField(max_length=100)
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name="owned_groups")
    members = models.ManyToManyField(User, related_name="friend_groups", blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.name} ({self.owner})"


class Notification(models.Model):
    TYPES = [
        ("bill_added", "Добавлен в счёт"),
        ("debt_paid", "Долг оплачен"),
        ("debt_created", "Новый долг"),
        ("new_message", "Новое сообщение"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="notifications")
    type = models.CharField(max_length=50, choices=TYPES)
    title = models.CharField(max_length=255)
    body = models.TextField(blank=True, default="")
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.type}: {self.title} ({self.user})"
