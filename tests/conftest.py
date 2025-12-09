import os
import sys
from pathlib import Path
import asyncio
import pytest
from fastapi.testclient import TestClient

# Ensure backend/app is importable
BASE_DIR = Path(__file__).resolve().parents[1]
APP_DIR = BASE_DIR / "app"
sys.path.insert(0, str(BASE_DIR))
sys.path.insert(0, str(APP_DIR))

# Configure temp dirs BEFORE importing app to avoid StaticFiles error
from app.config import settings
TMP_UPLOAD = None
TMP_PUBLIC = None

def _prepare_temp_dirs(tmp_path_factory):
    global TMP_UPLOAD, TMP_PUBLIC
    base_tmp = tmp_path_factory.mktemp("be_tmp")
    TMP_UPLOAD = base_tmp / "uploads"
    TMP_PUBLIC = base_tmp / "public"
    TMP_UPLOAD.mkdir(parents=True, exist_ok=True)
    TMP_PUBLIC.mkdir(parents=True, exist_ok=True)
    # Patch settings to point to temp dirs
    setattr(settings, "UPLOAD_DIR", str(TMP_UPLOAD))
    setattr(settings, "PUBLIC_DIR", str(TMP_PUBLIC))
    setattr(settings, "CLEANUP_INTERVAL", 1)


app = None

@pytest.fixture(scope="session", autouse=True)
def setup_session_dirs(tmp_path_factory):
    """Session-level: create temp dirs, patch settings, and import app."""
    global app
    _prepare_temp_dirs(tmp_path_factory)
    # Now import the app after directories are set up
    from app.main import app as fastapi_app
    app = fastapi_app
    return

@pytest.fixture(autouse=True)
def setup_dirs(monkeypatch):
    """Per-test: keep settings pointing to session temp dirs."""
    monkeypatch.setattr(settings, "UPLOAD_DIR", str(TMP_UPLOAD))
    monkeypatch.setattr(settings, "PUBLIC_DIR", str(TMP_PUBLIC))
    monkeypatch.setattr(settings, "CLEANUP_INTERVAL", 1)
    yield


@pytest.fixture()
def client():
    global app
    assert app is not None, "FastAPI app not initialized"
    return TestClient(app)
