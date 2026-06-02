from datetime import datetime
from fastapi import Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from backend.core.database import get_db
from backend.core.security import decode_token
from backend.models.user import User, UserRole

security = HTTPBearer()
security_optional = HTTPBearer(auto_error=False)


def _check_token_revoked(user: User, payload: dict) -> None:
    """Raise 401 if the token was issued before the user's revocation timestamp."""
    if user.tokens_invalidated_at is None:
        return
    iat = payload.get("iat")
    if iat is None:
        return
    issued_at = datetime.utcfromtimestamp(iat)
    if issued_at < user.tokens_invalidated_at.replace(tzinfo=None):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has been revoked. Please log in again."
        )


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    token = credentials.credentials
    payload = decode_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    _check_token_revoked(user, payload)
    return user


def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(security_optional),
    db: Session = Depends(get_db)
):
    if not credentials:
        return None
    payload = decode_token(credentials.credentials)
    if not payload:
        return None
    user_id = payload.get("sub")
    if not user_id:
        return None
    user = db.query(User).filter(User.id == int(user_id), User.is_active == True).first()
    if user:
        try:
            _check_token_revoked(user, payload)
        except HTTPException:
            return None
    return user


# ── RBAC helpers ────────────────────────────────────────────────────────────

def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user


def require_staff_or_above(current_user: User = Depends(get_current_user)) -> User:
    """Staff, Branch Manager, or Admin."""
    if current_user.role not in [UserRole.staff, UserRole.branch_manager, UserRole.admin]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Staff access required")
    return current_user


def require_branch_manager_or_above(current_user: User = Depends(get_current_user)) -> User:
    """Branch Manager or Admin."""
    if current_user.role not in [UserRole.branch_manager, UserRole.admin]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Branch manager access required")
    return current_user


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.admin:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return current_user
