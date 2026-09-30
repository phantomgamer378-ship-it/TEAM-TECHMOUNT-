from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/v1/auth", tags=["auth"])

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str

@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest):
    # Stub implementation for Phase 11 requirement
    if req.username == "admin" and req.password == "admin":
        return {"access_token": "mock_jwt_token", "token_type": "bearer"}
    raise HTTPException(status_code=401, detail="Invalid credentials")
