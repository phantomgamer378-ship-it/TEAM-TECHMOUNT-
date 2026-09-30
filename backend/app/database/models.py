from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import String, Float, Integer, Boolean, DateTime, ForeignKey, JSON
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

def _now():
    return datetime.now(timezone.utc)

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    username: Mapped[str] = mapped_column(String, unique=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    devices: Mapped[List["Device"]] = relationship(back_populates="user")
    trusted_contacts: Mapped[List["TrustedContact"]] = relationship(back_populates="user")
    voice_profiles: Mapped[List["VoiceProfile"]] = relationship(back_populates="user")

class Device(Base):
    __tablename__ = "devices"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    device_id: Mapped[str] = mapped_column(String, unique=True, index=True)
    platform: Mapped[str] = mapped_column(String)  # "android", "ios", "web"
    fcm_token: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    
    user: Mapped["User"] = relationship(back_populates="devices")

class TrustedContact(Base):
    __tablename__ = "trusted_contacts"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    phone_number: Mapped[str] = mapped_column(String)
    name: Mapped[str] = mapped_column(String)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    user: Mapped["User"] = relationship(back_populates="trusted_contacts")

class VoiceProfile(Base):
    __tablename__ = "voice_profiles"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True)
    label: Mapped[str] = mapped_column(String)
    reference_meta: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    user: Mapped[Optional["User"]] = relationship(back_populates="voice_profiles")

class CallSession(Base):
    __tablename__ = "calls"
    id: Mapped[str] = mapped_column(String, primary_key=True)  # session_id
    user_id: Mapped[Optional[int]] = mapped_column(ForeignKey("users.id"), nullable=True)
    source: Mapped[str] = mapped_column(String)
    status: Mapped[str] = mapped_column(String, default="active") # active, completed
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    events: Mapped[List["CallEvent"]] = relationship(back_populates="call")
    analysis_results: Mapped[List["AnalysisResult"]] = relationship(back_populates="call")

class CallEvent(Base):
    __tablename__ = "call_events"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("calls.id"))
    event_type: Mapped[str] = mapped_column(String)
    payload: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    call: Mapped["CallSession"] = relationship(back_populates="events")

class AnalysisResult(Base):
    __tablename__ = "analysis_results"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("calls.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    duration_s: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    language: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    spoof_risk: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    scam_risk: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    risk_score: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    risk_level: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    attack_types: Mapped[list] = mapped_column(JSON, default=list)
    indicators: Mapped[list] = mapped_column(JSON, default=list)
    fallback_used: Mapped[bool] = mapped_column(Boolean, default=False)
    result_json: Mapped[dict] = mapped_column(JSON)

    call: Mapped["CallSession"] = relationship(back_populates="analysis_results")

class Threat(Base):
    __tablename__ = "threats"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("calls.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    risk_level: Mapped[str] = mapped_column(String)
    attack_types: Mapped[list] = mapped_column(JSON, default=list)
    action: Mapped[Optional[str]] = mapped_column(String, nullable=True)

class LivenessSession(Base):
    __tablename__ = "liveness_sessions"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(ForeignKey("calls.id"))
    challenge: Mapped[str] = mapped_column(String)
    status: Mapped[str] = mapped_column(String, default="PENDING")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    verified_at: Mapped[Optional[datetime]] = mapped_column(DateTime, nullable=True)

class MessageScan(Base):
    __tablename__ = "message_scans"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    content_hash: Mapped[str] = mapped_column(String, index=True)
    scam_score: Mapped[float] = mapped_column(Float)
    indicators: Mapped[list] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

class UrlScan(Base):
    __tablename__ = "url_scans"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    url: Mapped[str] = mapped_column(String, index=True)
    is_malicious: Mapped[bool] = mapped_column(Boolean, default=False)
    reasons: Mapped[list] = mapped_column(JSON, default=list)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

class SecuritySetting(Base):
    __tablename__ = "security_settings"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    auto_block_scams: Mapped[bool] = mapped_column(Boolean, default=True)
    require_liveness_on_unknown: Mapped[bool] = mapped_column(Boolean, default=False)

class ModelVersion(Base):
    __tablename__ = "model_versions"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    model_name: Mapped[str] = mapped_column(String)
    version: Mapped[str] = mapped_column(String)
    active: Mapped[bool] = mapped_column(Boolean, default=False)
    deployed_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
