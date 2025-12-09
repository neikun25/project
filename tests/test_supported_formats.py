def test_supported_formats_all(client):
    resp = client.get("/supported-formats")
    assert resp.status_code == 200
    data = resp.json()
    assert "document" in data
    assert "audio" in data
    assert isinstance(data["document"]["allowedExtensions"], list)
    assert isinstance(data["audio"]["allowedExtensions"], list)

def test_supported_formats_document_only(client):
    resp = client.get("/supported-formats", params={"category": "document"})
    assert resp.status_code == 200
    data = resp.json()
    assert "document" in data and "audio" not in data

def test_supported_formats_invalid_category(client):
    resp = client.get("/supported-formats", params={"category": "video"})
    assert resp.status_code == 400
