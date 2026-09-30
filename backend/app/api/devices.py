from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session
from app.database.session import get_db
from app.database.models import Device
from pydantic import BaseModel
from typing import List

router = APIRouter(prefix="/v1/devices", tags=["devices"])

class DeviceCreate(BaseModel):
    user_id: int
    device_id: str
    platform: str
    fcm_token: str = None

class DeviceResponse(BaseModel):
    id: int
    device_id: str
    platform: str
    
    class Config:
        from_attributes = True

@router.post("/", response_model=DeviceResponse)
def register_device(device: DeviceCreate, db: Session = Depends(get_db)):
    db_dev = db.query(Device).filter(Device.device_id == device.device_id).first()
    if db_dev:
        return db_dev # Idempotent registration
        
    new_dev = Device(
        user_id=device.user_id,
        device_id=device.device_id,
        platform=device.platform,
        fcm_token=device.fcm_token
    )
    db.add(new_dev)
    db.commit()
    db.refresh(new_dev)
    return new_dev
