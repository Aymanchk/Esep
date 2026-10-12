from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import Bill, Debt, FriendGroup, Notification

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    username = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ["id", "username", "email", "phone", "password", "first_name"]

    def create(self, validated_data):
        password = validated_data.pop("password")
        # Use email as username if username not provided
        if not validated_data.get("username"):
            validated_data["username"] = validated_data["email"]
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="first_name")
    avatar = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "name", "email", "phone", "avatar"]

    def get_avatar(self, obj):
        if obj.avatar:
            request = self.context.get("request")
            if request:
                return request.build_absolute_uri(obj.avatar.url)
            return obj.avatar.url
        return None


class ProfileUpdateSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="first_name", required=False)

    class Meta:
        model = User
        fields = ["name", "email", "phone"]


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()


class BillSerializer(serializers.ModelSerializer):
    class Meta:
        model = Bill
        fields = [
            "id",
            "total",
            "service_charge_percent",
            "items",
            "people",
            "assignments",
            "title",
            "currency",
            "category",
            "split_mode",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def create(self, validated_data):
        validated_data["user"] = self.context["request"].user
        return super().create(validated_data)


class DebtSerializer(serializers.ModelSerializer):
    from_user = UserSerializer(read_only=True)
    to_user = UserSerializer(read_only=True)
    from_user_id = serializers.IntegerField(write_only=True, required=False)
    to_user_id = serializers.IntegerField(write_only=True, required=False)

    class Meta:
        model = Debt
        fields = [
            "id", "from_user", "to_user", "from_user_id", "to_user_id",
            "amount", "bill", "description", "is_paid",
            "created_at", "paid_at",
        ]
        read_only_fields = ["id", "created_at", "paid_at"]

    def create(self, validated_data):
        from_user_id = validated_data.pop("from_user_id", None)
        to_user_id = validated_data.pop("to_user_id", None)
        request_user = self.context["request"].user

        if from_user_id and to_user_id:
            # Caller specified direction — must include current user.
            if request_user.id not in (from_user_id, to_user_id):
                raise serializers.ValidationError(
                    "Вы должны быть участником долга"
                )
            try:
                validated_data["from_user"] = User.objects.get(id=from_user_id)
                validated_data["to_user"] = User.objects.get(id=to_user_id)
            except User.DoesNotExist:
                raise serializers.ValidationError("Пользователь не найден")
        elif to_user_id:
            # Backward-compat: current user owes selected user.
            validated_data["from_user"] = request_user
            try:
                validated_data["to_user"] = User.objects.get(id=to_user_id)
            except User.DoesNotExist:
                raise serializers.ValidationError("Пользователь не найден")
        else:
            raise serializers.ValidationError("Не указаны участники долга")

        return super().create(validated_data)


class FriendGroupSerializer(serializers.ModelSerializer):
    members = UserSerializer(many=True, read_only=True)
    member_ids = serializers.ListField(
        child=serializers.IntegerField(), write_only=True, required=False
    )
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = FriendGroup
        fields = ["id", "name", "members", "member_ids", "member_count", "created_at"]
        read_only_fields = ["id", "created_at"]

    def get_member_count(self, obj):
        return obj.members.count()

    def create(self, validated_data):
        member_ids = validated_data.pop("member_ids", [])
        validated_data["owner"] = self.context["request"].user
        group = super().create(validated_data)
        if member_ids:
            group.members.set(member_ids)
        return group

    def update(self, instance, validated_data):
        member_ids = validated_data.pop("member_ids", None)
        instance = super().update(instance, validated_data)
        if member_ids is not None:
            instance.members.set(member_ids)
        return instance


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "type", "title", "body", "data", "is_read", "created_at"]
        read_only_fields = ["id", "created_at"]



