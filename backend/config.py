"""Ayarlari backend/.env dosyasindan okur.

Kimlik bilgileri (veritabani sifresi, Google API anahtari) kaynak koda
gomulmez. Sablon icin .env.example dosyasina bakin:

    cp .env.example .env
"""

import os
from pathlib import Path

ENV_PATH = Path(__file__).resolve().parent / ".env"


def _load_env(path=ENV_PATH):
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):].lstrip()
        key, sep, value = line.partition("=")
        if not sep:
            continue
        key, value = key.strip(), value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        if key and key not in os.environ:
            os.environ[key] = value


_load_env()


def get(name, default=None, required=False):
    value = os.environ.get(name, default)
    if required and not value:
        raise RuntimeError(
            f"'{name}' ayari bulunamadi.\n"
            f"backend/.env dosyasini olusturup bu degeri girin:\n"
            f"    cd backend && cp .env.example .env"
        )
    return value


GOOGLE_API_KEY = get("GOOGLE_API_KEY", required=True)

DB_CONFIG = {
    "host": get("DB_HOST", "localhost"),
    "user": get("DB_USER", "root"),
    "password": get("DB_PASSWORD", required=True),
    "database": get("DB_NAME", "gezintoo_db"),
}
