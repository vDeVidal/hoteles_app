# app/config.py
from typing import Optional, List
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field, AliasChoices

class Settings(BaseSettings):
    # Opción 1: URL completa (si alguna vez la usas)
    DATABASE_URL: Optional[str] = Field(default=None, validation_alias="DATABASE_URL")

    # Opción 2: Componentes (usando tus nombres exactos)
    DB_USER: Optional[str] = Field(default=None, validation_alias="DB_USER")
    DB_PASSWORD: Optional[str] = Field(
        default=None,
        validation_alias=AliasChoices("DB_PASSWORD", "DB_PASS")   # <- tu .env usa DB_PASS
    )
    DB_HOST: str = Field(default="127.0.0.1", validation_alias=AliasChoices("DB_HOST", "MYSQL_HOST"))
    DB_PORT: int = Field(default=3306, validation_alias=AliasChoices("DB_PORT", "MYSQL_PORT"))
    DB_NAME: Optional[str] = Field(default=None, validation_alias=AliasChoices("DB_NAME", "MYSQL_DB", "DB"))

    # JWT/seguridad (tu .env usa WT_SECRET)
    SECRET_KEY: str = Field(default="change-me", validation_alias=AliasChoices("SECRET_KEY", "JWT_SECRET", "WT_SECRET"))
    ALGORITHM: str = Field(default="HS256", validation_alias=AliasChoices("ALGORITHM", "JWT_ALG"))
    ACCESS_TOKEN_EXPIRE_MINUTES: int = Field(default=60, validation_alias=AliasChoices("ACCESS_TOKEN_EXPIRE_MINUTES", "JWT_EXPIRE_MINUTES"))

    # CORS (tu .env usa ORS_ORIGINS)
    CORS_ORIGINS: str = Field(default="", validation_alias=AliasChoices("CORS_ORIGINS", "ORS_ORIGINS"))

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def cors_origins_list(self) -> List[str]:
        """
        Si ORS_ORIGINS == '*', devolvemos lista vacía y en main.py usamos ["*"].
        Si viene coma-separado, lo convertimos a lista.
        """
        raw = (self.CORS_ORIGINS or "").strip()
        if raw in ("", "*"):
            return []
        return [o.strip() for o in raw.split(",") if o.strip()]

settings = Settings()
