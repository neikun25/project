from app.utils.file_utils import format_file_size, detect_ext_by_name, build_public_url


def test_format_file_size():
    assert format_file_size(512) == "512 B"
    assert format_file_size(2048).endswith("KB")
    assert format_file_size(2 * 1024 * 1024).endswith("MB")


def test_detect_ext_by_name():
    assert detect_ext_by_name("file.DOCX") == ".docx"
    assert detect_ext_by_name("/path/to/audio.mp3") == ".mp3"


def test_build_public_url(settings=__import__("app.config", fromlist=["settings"]).settings):
    base = settings.PUBLIC_BASE_URL.rstrip("/")
    assert build_public_url("/preview/abc.pdf").startswith(base)
