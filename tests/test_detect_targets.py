from io import BytesIO
from pathlib import Path


def test_detect_targets_document(client):
    sample_file = Path(__file__).parent / "samples" / "sample.txt"
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        data = {"category": "document"}
        resp = client.post("/detect-targets", files=files, data=data)
    assert resp.status_code == 200
    body = resp.json()
    assert body["filename"] == "sample.txt"
    assert body["category"] == "document"
    assert isinstance(body["supportedTargets"], list)
    assert body["canConvert"] in (True, False)


def test_detect_targets_invalid_category(client):
    sample_file = Path(__file__).parent / "samples" / "sample.txt"
    with open(sample_file, "rb") as f:
        files = {"file": ("sample.txt", f, "text/plain")}
        data = {"category": "video"}
        resp = client.post("/detect-targets", files=files, data=data)
    assert resp.status_code == 400
