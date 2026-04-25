from rest_framework import generics, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db.models import Q, Sum, Count
from .models import Bill, ChatRoom, Message, Debt, FriendGroup, Notification
from .serializers import (
    RegisterSerializer,
    UserSerializer,
    LoginSerializer,
    BillSerializer,
    ProfileUpdateSerializer,
    ChatRoomSerializer,
    MessageSerializer,
    DebtSerializer,
    FriendGroupSerializer,
    NotificationSerializer,
)

User = get_user_model()


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


# --- Chat ---

@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def chat_rooms_view(request):
    if request.method == "GET":
        rooms = ChatRoom.objects.filter(participants=request.user)
        serializer = ChatRoomSerializer(
            rooms, many=True, context={"request": request}
        )
        return Response({"rooms": serializer.data})

    # POST — create or get existing 1:1 room
    participant_ids = request.data.get("participants", [])
    if not participant_ids:
        return Response(
            {"error": "Укажите участников"}, status=status.HTTP_400_BAD_REQUEST
        )

    all_ids = set(participant_ids + [request.user.id])

    # Check for existing room with same participants
    for room in ChatRoom.objects.filter(participants=request.user):
        room_ids = set(room.participants.values_list("id", flat=True))
        if room_ids == all_ids:
            return Response(
                ChatRoomSerializer(room, context={"request": request}).data
            )

    # Create new room
    room = ChatRoom.objects.create()
    room.participants.set(all_ids)
    return Response(
        ChatRoomSerializer(room, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def chat_messages_view(request, room_id):
    try:
        room = ChatRoom.objects.get(id=room_id, participants=request.user)
    except ChatRoom.DoesNotExist:
        return Response({"error": "Чат не найден"}, status=status.HTTP_404_NOT_FOUND)

    messages = room.messages.all()
    before = request.query_params.get("before")
    if before:
        try:
            messages = messages.filter(id__lt=int(before))
        except ValueError:
            return Response({"error": "Неверный параметр before"}, status=status.HTTP_400_BAD_REQUEST)
    messages = messages.order_by("-created_at")[:50]

    return Response(
        {"messages": MessageSerializer(
            reversed(list(messages)), many=True, context={"request": request}
        ).data}
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def chat_send_message_view(request, room_id):
    try:
        room = ChatRoom.objects.get(id=room_id, participants=request.user)
    except ChatRoom.DoesNotExist:
        return Response({"error": "Чат не найден"}, status=status.HTTP_404_NOT_FOUND)

    text = request.data.get("text", "").strip()
    if not text:
        return Response(
            {"error": "Пустое сообщение"}, status=status.HTTP_400_BAD_REQUEST
        )

    message = Message.objects.create(room=room, sender=request.user, text=text)
    return Response(
        MessageSerializer(message, context={"request": request}).data,
        status=status.HTTP_201_CREATED,
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def chat_mark_read_view(request, room_id):
    try:
        room = ChatRoom.objects.get(id=room_id, participants=request.user)
    except ChatRoom.DoesNotExist:
        return Response({"error": "Чат не найден"}, status=status.HTTP_404_NOT_FOUND)

    room.messages.filter(is_read=False).exclude(sender=request.user).update(is_read=True)
    return Response({"status": "ok"})


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
