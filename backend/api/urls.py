from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path("auth/register/", views.register_view, name="register"),
    path("auth/login/", views.login_view, name="login"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
    path("auth/me/", views.profile_view, name="profile"),
    path("auth/me/avatar/", views.upload_avatar, name="upload-avatar"),
    # Users
    path("users/search/", views.search_users, name="user-search"),
    # Chat
    path("chat/rooms/", views.chat_rooms_view, name="chat-rooms"),
    path("chat/rooms/<int:room_id>/messages/", views.chat_messages_view, name="chat-messages"),
    path("chat/rooms/<int:room_id>/send/", views.chat_send_message_view, name="chat-send"),
    path("chat/rooms/<int:room_id>/read/", views.chat_mark_read_view, name="chat-mark-read"),
    # Bills
    path("bills/", views.BillListCreateView.as_view(), name="bill-list"),
    path("bills/<int:pk>/", views.BillDetailView.as_view(), name="bill-detail"),
    # Debts
    path("debts/", views.debts_view, name="debts"),
    path("debts/settle/", views.debt_settle_view, name="debt-settle"),
    path("debts/<int:debt_id>/pay/", views.debt_mark_paid_view, name="debt-pay"),
    path("debts/summary/", views.debt_summary_view, name="debt-summary"),
    # Friend Groups
    path("groups/", views.groups_view, name="groups"),
    path("groups/<int:group_id>/", views.group_detail_view, name="group-detail"),
    # Notifications
    path("notifications/", views.notifications_view, name="notifications"),
    path("notifications/read/", views.notifications_read_view, name="notifications-read"),
    path("notifications/<int:notification_id>/read/", views.notification_read_single_view, name="notification-read"),
    # Statistics
    path("stats/", views.stats_view, name="stats"),
]
