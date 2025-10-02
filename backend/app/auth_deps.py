from fastapi import Depends, HTTPException, status
from typing import Any, Dict
from .security import verify_token

def get_current_claims(token: str = Depends(verify_token)) -> Dict[str, Any]:
    return token

def require_role(required_role: int):
    def _checker(claims: Dict[str, Any] = Depends(get_current_claims)) -> None:
        role = claims.get("role")
        try:
            role = int(role)
        except Exception:
            role = 0
        if role != required_role:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado"
            )
    return _checker


# ✅ Nuevo: permitir varios roles
def require_any_role(allowed: list[int]):
    """
    Permite acceso si el claim 'role' está en la lista 'allowed'.
    """
    def _checker(claims: Dict[str, Any] = Depends(get_current_claims)) -> None:
        role = claims.get("role")
        try:
            role = int(role)
        except Exception:
            role = 0
        if role not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="No autorizado"
            )
    return _checker
