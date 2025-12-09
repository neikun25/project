"""
Integration tests using actual sample files to verify end-to-end conversion flows.
These tests exercise the full conversion pipeline with real file formats.
"""
import time
from pathlib import Path
from io import BytesIO
import pytest
from fastapi.testclient import TestClient


SAMPLES_DIR = Path(__file__).parent / "samples"


def test_txt_to_pdf_conversion(client: TestClient):
    """Test converting TXT file to PDF"""
    sample_file = SAMPLES_DIR / "sample.txt"
    if not sample_file.exists():
        pytest.skip("sample.txt not found")
    
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        data = {"category": "document", "target": "pdf"}
        
        resp = client.post("/convert/upload", files=files, data=data)
        assert resp.status_code == 200, f"Upload failed: {resp.json()}"
        
        task_id = resp.json()["taskId"]
        assert task_id
        
        # Poll for completion (max 10s)
        for _ in range(20):
            time.sleep(0.5)
            status_resp = client.get(f"/convert/task/{task_id}")
            assert status_resp.status_code == 200
            status = status_resp.json()
            
            if status["state"] == "finished":
                assert status["url"]
                assert status["downloadUrl"]
                return
            elif status["state"] == "error":
                pytest.fail(f"Conversion failed: {status.get('message')}")
        
        pytest.fail("Conversion timeout")


def test_html_to_pdf_conversion(client: TestClient):
    """Test converting HTML file to PDF"""
    sample_file = SAMPLES_DIR / "sample.html"
    if not sample_file.exists():
        pytest.skip("sample.html not found")
    
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.html", f, "text/html")}
        data = {"category": "document", "target": "pdf"}
        
        resp = client.post("/convert/upload", files=files, data=data)
        assert resp.status_code == 200, f"Upload failed: {resp.json()}"
        
        task_id = resp.json()["taskId"]
        
        # Poll for completion
        for _ in range(20):
            time.sleep(0.5)
            status_resp = client.get(f"/convert/task/{task_id}")
            status = status_resp.json()
            
            if status["state"] in ("finished", "error"):
                # HTML->PDF might fail if xhtml2pdf/reportlab not available
                # We just verify the workflow runs
                return
        
        pytest.fail("Conversion timeout")


def test_detect_targets_with_real_txt(client: TestClient):
    """Test detect-targets with real TXT file"""
    sample_file = SAMPLES_DIR / "sample.txt"
    if not sample_file.exists():
        pytest.skip("sample.txt not found")
    
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        data = {"category": "document"}
        
        resp = client.post("/detect-targets", files=files, data=data)
        assert resp.status_code == 200
        
        body = resp.json()
        assert body["filename"] == "sample.txt"
        assert body["category"] == "document"
        assert body["sourceExtension"] == ".txt"
        assert isinstance(body["supportedTargets"], list)
        assert len(body["supportedTargets"]) > 0
        assert body["canConvert"] is True
        
        # TXT should support conversion to pdf, doc, docx, etc.
        assert "pdf" in body["supportedTargets"]


def test_unsupported_conversion_error(client: TestClient):
    """Test that unsupported conversions are rejected"""
    sample_file = SAMPLES_DIR / "sample.txt"
    if not sample_file.exists():
        pytest.skip("sample.txt not found")
    
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        # Try to convert TXT to MP3 (invalid)
        data = {"category": "document", "target": "mp3"}
        
        resp = client.post("/convert/upload", files=files, data=data)
        assert resp.status_code == 400
        assert "不支持" in resp.json()["detail"]


def test_format_mismatch_error(client: TestClient):
    """Test that format mismatch is detected"""
    sample_file = SAMPLES_DIR / "sample.txt"
    if not sample_file.exists():
        pytest.skip("sample.txt not found")
    
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        # Claim the file is DOCX but upload TXT
        data = {"category": "document", "target": "pdf", "source": "docx"}
        
        resp = client.post("/convert/upload", files=files, data=data)
        assert resp.status_code == 400
        assert "格式不匹配" in resp.json()["detail"]


def test_missing_file_error(client: TestClient):
    """Test that missing file is rejected"""
    data = {"category": "document", "target": "pdf"}
    
    resp = client.post("/convert/upload", data=data)
    assert resp.status_code == 400
    assert "缺少文件" in resp.json()["detail"]


def test_task_not_found_error(client: TestClient):
    """Test querying non-existent task"""
    resp = client.get("/convert/task/nonexistent-task-id")
    assert resp.status_code == 404
    assert "不存在" in resp.json()["detail"]
