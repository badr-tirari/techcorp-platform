"""Tests unitaires de l'API M-Motors (Activité Type 2, question 1)."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_my_test():
    """MY Test : la route racine renvoie Hello World."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello World"}


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_documents_sans_bucket_configure(monkeypatch):
    monkeypatch.delenv("DOCUMENTS_BUCKET", raising=False)
    response = client.get("/dossiers/LOC-2026-001/documents")
    assert response.status_code == 503


def test_documents_identifiant_invalide():
    response = client.get("/dossiers/..%2F..%2Fetc/documents")
    assert response.status_code in (400, 404)
