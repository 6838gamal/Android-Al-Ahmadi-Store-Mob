from sqlalchemy.orm import Session
from backend.models.notification import Notification, NotificationType


def push_notification(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    notif_type: NotificationType = NotificationType.system,
    is_important: bool = False,
    reference_id: int = None,
    reference_type: str = None,
) -> None:
    """Create a single in-app notification record."""
    if not user_id:
        return
    notif = Notification(
        user_id=user_id,
        title=title,
        body=body,
        notification_type=notif_type,
        is_important=is_important,
        reference_id=reference_id,
        reference_type=reference_type,
    )
    db.add(notif)


def push_notification_to_admins(
    db: Session,
    title: str,
    body: str,
    notif_type: NotificationType = NotificationType.system,
    is_important: bool = False,
    reference_id: int = None,
    reference_type: str = None,
) -> None:
    """Send a notification to all active admin users."""
    from backend.models.user import User, UserRole
    admins = db.query(User).filter(
        User.role == UserRole.admin,
        User.is_active == True,
    ).all()
    for admin in admins:
        push_notification(
            db, admin.id, title, body,
            notif_type=notif_type,
            is_important=is_important,
            reference_id=reference_id,
            reference_type=reference_type,
        )
