"""
Suite de tests exécutée contre l'environnement de test (docker-compose.test.yml),
avant toute mise en production sur Kubernetes.
Compétence CCP2 : "Préparer un environnement de test"
"""
import os
import requests
import pytest

BASE_URL = os.getenv("TEST_BASE_URL", "http://localhost:8001")


def test_health_check():
    resp = requests.get(f"{BASE_URL}/health", timeout=5)
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"


def test_metrics_endpoint():
    """Vérifie que le point de métriques scrapé par Prometheus (CCP3) répond."""
    resp = requests.get(f"{BASE_URL}/metrics", timeout=5)
    assert resp.status_code == 200
    assert b"http_requests_total" in resp.content


def test_create_order():
    payload = {"customer_name": "Jean Dupont", "product": "Licence DevOps", "status": "pending"}
    resp = requests.post(f"{BASE_URL}/orders", json=payload, timeout=5)
    assert resp.status_code == 201
    body = resp.json()
    assert body["customer_name"] == "Jean Dupont"
    assert "id" in body


def test_list_orders():
    resp = requests.get(f"{BASE_URL}/orders", timeout=5)
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)
    assert len(resp.json()) >= 1


def test_get_order_not_found():
    resp = requests.get(f"{BASE_URL}/orders/999999", timeout=5)
    assert resp.status_code == 404


def test_get_order_found():
    payload = {"customer_name": "Marie Curie", "product": "Formation Cloud", "status": "pending"}
    created = requests.post(f"{BASE_URL}/orders", json=payload, timeout=5).json()
    resp = requests.get(f"{BASE_URL}/orders/{created['id']}", timeout=5)
    assert resp.status_code == 200
    assert resp.json()["customer_name"] == "Marie Curie"
