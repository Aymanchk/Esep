from django.urls import path
from . import views

urlpatterns = [
    # Auth
    path("auth/register/", views.register_view, name="register"),
    path("auth/login/", views.login_view, name="login"),
    path("auth/otp/send/", views.send_otp_view, name="send-otp"),
    path("auth/otp/verify/", views.verify_otp_view, name="verify-otp"),
    path("auth/telegram/", views.telegram_auth_view, name="telegram-auth"),
    path("auth/me/", views.profile_view, name="profile"),
    path("auth/me/avatar/", views.upload_avatar, name="upload-avatar"),
    # Users
    path("users/search/", views.search_users, name="user-search"),

    # Bills
    path("bills/", views.BillListCreateView.as_view(), name="bill-list"),
    path("bills/<int:pk>/", views.BillDetailView.as_view(), name="bill-detail"),
    # Debts
    path("debts/", views.debts_view, name="debts"),
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
    # OCR Scanner (AI-powered)
    path("ocr/scan/", views.ocr_scan_view, name="ocr-scan"),
]
