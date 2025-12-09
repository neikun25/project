import os
from io import BytesIO
from pathlib import Path
from fastapi.testclient import TestClient
import pytest

from app.utils.task_manager import task_manager

@pytest.fixture(autouse=True)
def patch_conversion(monkeypatch):
    """Patch heavy conversion to a lightweight stub that writes an output file."""
    from app.routers import convert as convert_router

    async def fake_convert_async(task):
        # simulate quick success and output file creation
        output_dir = Path(__import__("app.config", fromlist=["settings"]).settings.PUBLIC_DIR)
        output_dir.mkdir(parents=True, exist_ok=True)
        friendly_name = (task.original_filename or "document") + "_test"
        out_path = output_dir / f"{friendly_name}.{task.target}"
        out_path.write_bytes(b"converted")
        task.output_path = str(out_path)
        task.url = f"/public/{out_path.name}"
        task.download_url = f"/download/{out_path.name}"
        task.preview_url = f"/preview/{out_path.name}"
        from app.models import TaskState
        task.state = TaskState.FINISHED
        task_manager.update_task(task)

    monkeypatch.setattr(convert_router, "convert_async", fake_convert_async)
    yield


def test_upload_and_task_status_document(client: TestClient):
    sample_file = Path(__file__).parent / "samples" / "sample.txt"
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        data = {"category": "document", "target": "pdf"}
        resp = client.post("/convert/upload", files=files, data=data)
    assert resp.status_code == 200
    task_id = resp.json()["taskId"]
    assert task_id

    # query status
    status = client.get(f"/convert/task/{task_id}")
    assert status.status_code == 200
    s = status.json()
    assert s["state"] in ("finished", "processing", "queued")


def test_download_and_preview_routes(client: TestClient, tmp_path):
    # create a file in public dir
    public_dir = Path(__import__("app.config", fromlist=["settings"]).settings.PUBLIC_DIR)
    fname = "example.pdf"
    fpath = public_dir / fname
    fpath.write_bytes(b"content")

    # preview
    prev = client.get(f"/preview/{fname}")
    assert prev.status_code == 200

    # download
    down = client.get(f"/download/{fname}")
    assert down.status_code == 200
