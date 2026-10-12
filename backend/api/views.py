from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes, throttle_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.throttling import AnonRateThrottle
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db.models import Q, Sum, Count
from django.conf import settings
from datetime import timedelta
import hmac
import hashlib
import random
import json
import threading
import requests
from urllib.parse import parse_qsl
from .models import Bill, Debt, FriendGroup, Notification, PhoneOTP
from .serializers import (
    RegisterSerializer,
    UserSerializer,
    LoginSerializer,
    BillSerializer,
    ProfileUpdateSerializer,
    DebtSerializer,
    FriendGroupSerializer,
    NotificationSerializer,
)

User = get_user_model()


class OtpRequestThrottle(AnonRateThrottle):
    scope = "otp_request"


class OtpVerifyThrottle(AnonRateThrottle):
    scope = "otp_verify"


class OcrScanThrottle(AnonRateThrottle):
    scope = "ocr_scan"


def get_tokens_for_user(user):
    refresh = RefreshToken.for_user(user)
    return {
        "access": str(refresh.access_token),
        "refresh": str(refresh),
    }


@api_view(["POST"])
@permission_classes([AllowAny])
def register_view(request):
    serializer = RegisterSerializer(data={
        "email": request.data.get("email"),
        "first_name": request.data.get("name", ""),
        "phone": request.data.get("phone"),
        "password": request.data.get("password"),
    })
    if serializer.is_valid():
        user = serializer.save()
        tokens = get_tokens_for_user(user)
        return Response(
            {
                "user": UserSerializer(user, context={"request": request}).data,
                "token": tokens["access"],
                "refresh": tokens["refresh"],
            },
            status=status.HTTP_201_CREATED,
        )
    return Response(
        {"error": next(iter(serializer.errors.values()))[0]},
        status=status.HTTP_400_BAD_REQUEST,
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def login_view(request):
    serializer = LoginSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(
            {"error": "Введите email и пароль"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    email = serializer.validated_data["email"]
    password = serializer.validated_data["password"]

    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response(
            {"error": "Неверный email или пароль"},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.check_password(password):
        return Response(
            {"error": "Неверный email или пароль"},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    tokens = get_tokens_for_user(user)
    return Response({
        "user": UserSerializer(user, context={"request": request}).data,
        "token": tokens["access"],
        "refresh": tokens["refresh"],
    })


def verify_telegram_init_data(init_data: str, bot_token: str) -> dict | None:
    try:
        parsed = dict(parse_qsl(init_data, keep_blank_values=True))
    except Exception:
        return None

    if "hash" not in parsed:
        return None

    received_hash = parsed.pop("hash")

    # Sort remaining fields alphabetically and join with \n
    sorted_items = sorted(parsed.items())
    data_check_string = "\n".join(f"{k}={v}" for k, v in sorted_items)

    # If bot_token is empty and settings.DEBUG is True, allow bypass for easy local development
    if not bot_token:
        if getattr(settings, "DEBUG", False):
            user_data = parsed.get("user")
            if user_data:
                try:
                    return json.loads(user_data)
                except Exception:
                    pass
        return None

    # Key = HMAC-SHA256("WebappData", bot_token)
    secret_key = hmac.new(b"WebappData", bot_token.encode(), hashlib.sha256).digest()

    # Hash = HMAC-SHA256(data_check_string, secret_key)
    computed_hash = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()

    if hmac.compare_digest(computed_hash, received_hash):
        user_data = parsed.get("user")
        if user_data:
            try:
                return json.loads(user_data)
            except Exception:
                pass
    return None


def send_telegram_message_async(chat_id, text, webapp_url=None):
    def target():
        token = getattr(settings, "TELEGRAM_BOT_TOKEN", "")
        if not token or not chat_id:
            return
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML"
        }
        if webapp_url:
            payload["reply_markup"] = {
                "inline_keyboard": [
                    [
                        {
                            "text": "Открыть FairSplitter",
                            "web_app": {"url": webapp_url}
                        }
                    ]
                ]
            }
        try:
            requests.post(url, json=payload, timeout=5)
        except Exception:
            pass

    threading.Thread(target=target).start()


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([OtpRequestThrottle])
def send_otp_view(request):
    phone = request.data.get("phone")
    if not phone:
        return Response({"error": "Введите номер телефона"}, status=status.HTTP_400_BAD_REQUEST)

    # Generate random 6-digit code
    code = f"{random.randint(100000, 999999)}"

    # Save code to PhoneOTP
    PhoneOTP.objects.update_or_create(phone=phone, defaults={"code": code})

    return Response({"success": True})


@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([OtpVerifyThrottle])
def verify_otp_view(request):
    phone = request.data.get("phone")
    code = request.data.get("code")
    if not phone or not code:
        return Response({"error": "Введите номер телефона и код"}, status=status.HTTP_400_BAD_REQUEST)

    is_valid = False

    # In debug/testing mode, accept test codes
    if code in ("123456", "000000") and getattr(settings, "DEBUG", False):
        is_valid = True
    else:
        try:
            otp = PhoneOTP.objects.get(phone=phone)
            expiry_cutoff = timezone.now() - timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
            if otp.code == code and otp.created_at >= expiry_cutoff:
                is_valid = True
                otp.delete()
        except PhoneOTP.DoesNotExist:
            pass

    if not is_valid:
        return Response({"error": "Неверный или просроченный код"}, status=status.HTTP_400_BAD_REQUEST)
        
    # Get or create user
    user, created = User.objects.get_or_create(phone=phone, defaults={
        "username": f"phone_{phone.replace('+', '').replace(' ', '')}",
        "email": f"phone_{phone}@fairsplitter.local",
    })
    
    if created:
        user.set_unusable_password()
        user.save()
        
    tokens = get_tokens_for_user(user)
    return Response({
        "user": UserSerializer(user, context={"request": request}).data,
        "token": tokens["access"],
        "refresh": tokens["refresh"],
    })


@api_view(["POST"])
@permission_classes([AllowAny])
def telegram_auth_view(request):
    init_data = request.data.get("initData")
    if not init_data:
        return Response({"error": "initData is required"}, status=status.HTTP_400_BAD_REQUEST)
        
    bot_token = getattr(settings, "TELEGRAM_BOT_TOKEN", "")
    tg_user = verify_telegram_init_data(init_data, bot_token)
    
    if not tg_user:
        return Response({"error": "Invalid Telegram signature or bot token not configured"}, status=status.HTTP_400_BAD_REQUEST)
        
    tg_id = str(tg_user.get("id"))
    first_name = tg_user.get("first_name", "")
    username = tg_user.get("username", "")
    
    try:
        user = User.objects.get(telegram_id=tg_id)
    except User.DoesNotExist:
        username_val = username or f"tg_{tg_id}"
        if User.objects.filter(username=username_val).exists():
            username_val = f"tg_{tg_id}"
            
        user = User.objects.create(
            telegram_id=tg_id,
            username=username_val,
            first_name=first_name,
            email=f"tg_{tg_id}@fairsplitter.local",
        )
        user.set_unusable_password()
        user.save()
        
    tokens = get_tokens_for_user(user)
    return Response({
        "user": UserSerializer(user, context={"request": request}).data,
        "token": tokens["access"],
        "refresh": tokens["refresh"],
    })


@api_view(["GET", "PATCH"])
@permission_classes([IsAuthenticated])
def profile_view(request):
    if request.method == "GET":
        return Response({"user": UserSerializer(request.user, context={"request": request}).data})
    serializer = ProfileUpdateSerializer(request.user, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response({"user": UserSerializer(request.user, context={"request": request}).data})
    return Response(
        {"error": next(iter(serializer.errors.values()))[0]},
        status=status.HTTP_400_BAD_REQUEST,
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def upload_avatar(request):
    if "avatar" not in request.FILES:
        return Response({"error": "Файл не найден"}, status=status.HTTP_400_BAD_REQUEST)
    request.user.avatar = request.FILES["avatar"]
    request.user.save()
    return Response({"user": UserSerializer(request.user, context={"request": request}).data})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def search_users(request):
    query = request.query_params.get("q", "").strip()
    if len(query) < 2:
        return Response({"results": []})
    users = User.objects.filter(
        Q(first_name__icontains=query)
        | Q(email__icontains=query)
        | Q(phone__icontains=query)
    ).exclude(id=request.user.id)[:20]
    return Response({"results": UserSerializer(users, many=True, context={"request": request}).data})


# --- Bills ---

def recalculate_and_simplify_debts():
    """
    Simplifies all active unpaid debts in the system using a greedy algorithm.
    """
    active_debts = list(Debt.objects.filter(is_paid=False))
    if not active_debts:
        return
        
    balances = {}
    user_objects = {}
    for d in active_debts:
        balances[d.from_user_id] = balances.get(d.from_user_id, 0.0) - float(d.amount)
        balances[d.to_user_id] = balances.get(d.to_user_id, 0.0) + float(d.amount)
        if d.from_user_id not in user_objects:
            user_objects[d.from_user_id] = d.from_user
        if d.to_user_id not in user_objects:
            user_objects[d.to_user_id] = d.to_user

    debtors = []
    creditors = []
    for uid, bal in balances.items():
        if bal < -0.01:
            debtors.append([uid, bal])
        elif bal > 0.01:
            creditors.append([uid, bal])

    debtors.sort(key=lambda x: x[1])
    creditors.sort(key=lambda x: x[1], reverse=True)

    new_debts = []
    i = 0
    j = 0
    while i < len(debtors) and j < len(creditors):
        debtor_id, debtor_bal = debtors[i]
        creditor_id, creditor_bal = creditors[j]

        amount_to_transfer = min(-debtor_bal, creditor_bal)
        amount_to_transfer = round(amount_to_transfer, 2)

        if amount_to_transfer > 0.01:
            new_debts.append(Debt(
                from_user=user_objects[debtor_id],
                to_user=user_objects[creditor_id],
                amount=amount_to_transfer,
                description="Упрощенный баланс",
                is_paid=False
            ))

        debtors[i][1] += amount_to_transfer
        creditors[j][1] -= amount_to_transfer

        if abs(debtors[i][1]) < 0.01:
            i += 1
        if abs(creditors[j][1]) < 0.01:
            j += 1

    from django.db import transaction
    with transaction.atomic():
        Debt.objects.filter(is_paid=False).delete()
        Debt.objects.bulk_create(new_debts)


class BillListCreateView(generics.ListCreateAPIView):
    serializer_class = BillSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Bill.objects.filter(user=self.request.user)

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        serializer = self.get_serializer(qs, many=True)
        return Response({"bills": serializer.data})

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        
        debts_data = request.data.get('debts', [])
        if isinstance(debts_data, list):
            for d in debts_data:
                from_uid = d.get('from_user_id')
                to_uid = d.get('to_user_id')
                amount = d.get('amount')
                desc = d.get('description', 'Разделение счёта')
                if from_uid and to_uid and amount and float(amount) > 0.01:
                    Debt.objects.create(
                        from_user_id=from_uid,
                        to_user_id=to_uid,
                        amount=float(amount),
                        description=desc,
                        is_paid=False
                    )
            recalculate_and_simplify_debts()
            
            # Send Telegram notifications to participants
            creator = request.user
            creator_name = creator.first_name or creator.username or "Ваш друг"
            title = serializer.validated_data.get("title") or "Без названия"
            total = serializer.validated_data.get("total") or 0
            referer = request.META.get('HTTP_REFERER', 'http://localhost:8080/')
            
            people_data = request.data.get('people', [])
            if isinstance(people_data, list):
                for p in people_data:
                    user_id = p.get('userId')
                    if user_id and int(user_id) != creator.id:
                        try:
                            participant = User.objects.get(id=user_id)
                            if participant.telegram_id:
                                msg = (
                                    f"<b>🍽️ Новый совместный счет!</b>\n\n"
                                    f"Пользователь <b>{creator_name}</b> разделил счет <b>«{title}»</b> на общую сумму <b>{float(total):,.0f} сом</b>.\n\n"
                                    f"Вы добавлены как участник. Откройте FairSplitter, чтобы посмотреть детали чека и ваши долги."
                                )
                                send_telegram_message_async(participant.telegram_id, msg, referer)
                        except (User.DoesNotExist, ValueError):
                            pass
            
        return Response({"bill": serializer.data}, status=status.HTTP_201_CREATED)


class BillDetailView(generics.RetrieveDestroyAPIView):
    serializer_class = BillSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Bill.objects.filter(user=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return Response({"bill": serializer.data})

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        self.perform_destroy(instance)
        return Response({"status": "ok"}, status=status.HTTP_200_OK)


# --- Debts ---

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def debts_view(request):
    if request.method == "GET":
        debts = Debt.objects.filter(
            Q(from_user=request.user) | Q(to_user=request.user)
        )
        show = request.query_params.get("show", "active")
        if show == "active":
            debts = debts.filter(is_paid=False)
        elif show == "paid":
            debts = debts.filter(is_paid=True)
        serializer = DebtSerializer(debts, many=True, context={"request": request})
        return Response({"debts": serializer.data})

    # POST — create debt
    serializer = DebtSerializer(data=request.data, context={"request": request})
    if not serializer.is_valid():
        return Response(
            {"error": next(iter(serializer.errors.values()))[0] if serializer.errors else "Ошибка"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    try:
        debt = serializer.save()
        recalculate_and_simplify_debts()
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

    # Notify debtor (if not the creator) and creditor (if not the creator).
    if debt.from_user_id != request.user.id:
        Notification.objects.create(
            user=debt.from_user,
            type="debt_created",
            title="Новый долг",
            body=f"Вы должны {debt.to_user.first_name} {debt.amount} сом",
            data={"debt_id": debt.id},
        )
    if debt.to_user_id != request.user.id:
        Notification.objects.create(
            user=debt.to_user,
            type="debt_created",
            title="Новый долг",
            body=f"{debt.from_user.first_name} должен вам {debt.amount} сом",
            data={"debt_id": debt.id},
        )
    return Response(
        DebtSerializer(debt, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def debt_mark_paid_view(request, debt_id):
    try:
        debt = Debt.objects.get(
            Q(from_user=request.user) | Q(to_user=request.user),
            id=debt_id,
        )
    except Debt.DoesNotExist:
        return Response({"error": "Долг не найден"}, status=status.HTTP_404_NOT_FOUND)

    debt.is_paid = True
    debt.paid_at = timezone.now()
    debt.save()

    # Notify the other party
    other_user = debt.to_user if debt.from_user == request.user else debt.from_user
    Notification.objects.create(
        user=other_user,
        type="debt_paid",
        title="Долг оплачен",
        body=f"{request.user.first_name} отметил долг {debt.amount} сом как оплаченный",
        data={"debt_id": debt.id},
    )

    recalculate_and_simplify_debts()

    return Response(DebtSerializer(debt, context={"request": request}).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def debt_summary_view(request):
    """Summary: who owes whom how much (net balances)."""
    user = request.user
    # Debts I owe (active)
    owed = Debt.objects.filter(from_user=user, is_paid=False).values(
        "to_user__id", "to_user__first_name"
    ).annotate(total=Sum("amount"))
    # Debts owed to me (active)
    received = Debt.objects.filter(to_user=user, is_paid=False).values(
        "from_user__id", "from_user__first_name"
    ).annotate(total=Sum("amount"))

    balances = {}
    for entry in owed:
        uid = entry["to_user__id"]
        balances[uid] = {
            "user_id": uid,
            "name": entry["to_user__first_name"],
            "balance": -float(entry["total"]),
        }
    for entry in received:
        uid = entry["from_user__id"]
        if uid in balances:
            balances[uid]["balance"] += float(entry["total"])
        else:
            balances[uid] = {
                "user_id": uid,
                "name": entry["from_user__first_name"],
                "balance": float(entry["total"]),
            }

    return Response({"balances": list(balances.values())})


# --- Friend Groups ---

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def groups_view(request):
    if request.method == "GET":
        groups = FriendGroup.objects.filter(owner=request.user)
        serializer = FriendGroupSerializer(groups, many=True, context={"request": request})
        return Response({"groups": serializer.data})

    serializer = FriendGroupSerializer(data=request.data, context={"request": request})
    if serializer.is_valid():
        group = serializer.save()
        return Response(
            FriendGroupSerializer(group, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )
    return Response(
        {"error": next(iter(serializer.errors.values()))[0]},
        status=status.HTTP_400_BAD_REQUEST,
    )


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([IsAuthenticated])
def group_detail_view(request, group_id):
    try:
        group = FriendGroup.objects.get(id=group_id, owner=request.user)
    except FriendGroup.DoesNotExist:
        return Response({"error": "Группа не найдена"}, status=status.HTTP_404_NOT_FOUND)

    if request.method == "GET":
        return Response(FriendGroupSerializer(group, context={"request": request}).data)

    if request.method == "DELETE":
        group.delete()
        return Response({"status": "ok"})

    # PATCH
    serializer = FriendGroupSerializer(group, data=request.data, partial=True, context={"request": request})
    if serializer.is_valid():
        group = serializer.save()
        return Response(FriendGroupSerializer(group, context={"request": request}).data)
    return Response(
        {"error": next(iter(serializer.errors.values()))[0]},
        status=status.HTTP_400_BAD_REQUEST,
    )


# --- Notifications ---

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def notifications_view(request):
    notifications = Notification.objects.filter(user=request.user)[:50]
    unread_count = Notification.objects.filter(user=request.user, is_read=False).count()
    serializer = NotificationSerializer(notifications, many=True)
    return Response({"notifications": serializer.data, "unread_count": unread_count})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def notifications_read_view(request):
    Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
    return Response({"status": "ok"})


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def notification_read_single_view(request, notification_id):
    Notification.objects.filter(id=notification_id, user=request.user).update(is_read=True)
    return Response({"status": "ok"})


# --- Statistics ---

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def stats_view(request):
    user = request.user
    bills = Bill.objects.filter(user=user)

    total_bills = bills.count()
    total_spent = bills.aggregate(total=Sum("total"))["total"] or 0

    # Monthly breakdown (last 6 months)
    from django.db.models.functions import TruncMonth
    monthly = (
        bills.annotate(month=TruncMonth("created_at"))
        .values("month")
        .annotate(total=Sum("total"), count=Count("id"))
        .order_by("-month")[:6]
    )

    # Weekly breakdown (last 4 weeks)
    from django.db.models.functions import TruncWeek
    weekly = (
        bills.annotate(week=TruncWeek("created_at"))
        .values("week")
        .annotate(total=Sum("total"), count=Count("id"))
        .order_by("-week")[:4]
    )

    # Top people (most frequent split partners)
    people_counter = {}
    for bill in bills:
        for person in bill.people:
            name = person.get("name", "Unknown")
            people_counter[name] = people_counter.get(name, 0) + 1
    top_people = sorted(people_counter.items(), key=lambda x: x[1], reverse=True)[:5]

    return Response({
        "total_bills": total_bills,
        "total_spent": float(total_spent),
        "monthly": [
            {"month": m["month"].isoformat(), "total": float(m["total"]), "count": m["count"]}
            for m in monthly
        ],
        "weekly": [
            {"week": w["week"].isoformat(), "total": float(w["total"]), "count": w["count"]}
            for w in weekly
        ],
        "top_people": [{"name": name, "count": count} for name, count in top_people],
    })


from .ocr_service import scan_receipt_with_gemini

@api_view(["POST"])
@permission_classes([AllowAny])
@throttle_classes([OcrScanThrottle])
def ocr_scan_view(request):
    if "image" not in request.FILES:
        return Response({"error": "Файл изображения не найден в запросе"}, status=status.HTTP_400_BAD_REQUEST)
    
    image_file = request.FILES["image"]
    image_bytes = image_file.read()
    mime_type = image_file.content_type or "image/jpeg"
    
    try:
        items = scan_receipt_with_gemini(image_bytes, mime_type)
        return Response({"items": items})
    except Exception as e:
        return Response({"error": str(e)}, status=status.HTTP_400_BAD_REQUEST)

