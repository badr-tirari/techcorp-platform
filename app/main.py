"""
TechCorp Order Tracker — application unique servant de support aux 3 CCP
du Titre Professionnel Administrateur Système DevOps :
  - CCP1 : infrastructure qui héberge cette application (Terraform + Ansible)
  - CCP2 : chaîne de déploiement continu de cette application (CI/CD + K8s)
  - CCP3 : supervision de cette application (Prometheus + Grafana + alerte)

API FastAPI + PostgreSQL volontairement simple : l'objectif du projet est
la chaîne complète infra -> déploiement -> supervision, pas la complexité métier.
"""
import os
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Response
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time as _time

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "techcorp_orders")
DB_USER = os.getenv("DB_USER", "techcorp")
DB_PASSWORD = os.getenv("DB_PASSWORD", "techcorp")

# --- Métriques Prometheus (CCP3 : indicateurs de supervision) ---------------
REQUEST_COUNT = Counter(
    "http_requests_total", "Nombre total de requêtes HTTP", ["method", "endpoint", "status"]
)
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds", "Durée des requêtes HTTP", ["endpoint"]
)
DB_HEALTH = Counter(
    "db_health_check_total", "Résultat des vérifications de santé de la base", ["result"]
)


def get_connection():
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=DB_USER, password=DB_PASSWORD,
        cursor_factory=RealDictCursor,
    )


def wait_for_db(max_retries=15, delay=2):
    for attempt in range(max_retries):
        try:
            conn = get_connection()
            conn.close()
            return
        except psycopg2.OperationalError:
            time.sleep(delay)
    raise RuntimeError("Base de données indisponible après plusieurs tentatives")


def init_db():
    wait_for_db()
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS orders (
                id SERIAL PRIMARY KEY,
                customer_name TEXT NOT NULL,
                product TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT NOW()
            );
        """)
    conn.commit()
    conn.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(title="TechCorp Order Tracker", version="2.0.0", lifespan=lifespan)


class OrderIn(BaseModel):
    customer_name: str
    product: str
    status: str = "pending"


class OrderOut(OrderIn):
    id: int


@app.middleware("http")
async def metrics_middleware(request, call_next):
    start = _time.time()
    response = await call_next(request)
    duration = _time.time() - start
    endpoint = request.url.path
    REQUEST_LATENCY.labels(endpoint=endpoint).observe(duration)
    REQUEST_COUNT.labels(method=request.method, endpoint=endpoint, status=response.status_code).inc()
    return response


@app.get("/health")
def health():
    try:
        conn = get_connection()
        conn.close()
        DB_HEALTH.labels(result="ok").inc()
        return {"status": "ok", "database": "connected"}
    except Exception as exc:
        DB_HEALTH.labels(result="fail").inc()
        raise HTTPException(status_code=503, detail=f"database unreachable: {exc}")


@app.get("/metrics")
def metrics():
    """Endpoint scrappé par Prometheus (CCP3)."""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/orders", response_model=OrderOut, status_code=201)
def create_order(order: OrderIn):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO orders (customer_name, product, status) VALUES (%s, %s, %s) RETURNING id, customer_name, product, status;",
            (order.customer_name, order.product, order.status),
        )
        row = cur.fetchone()
    conn.commit()
    conn.close()
    return row


@app.get("/orders", response_model=list[OrderOut])
def list_orders():
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id, customer_name, product, status FROM orders ORDER BY id;")
        rows = cur.fetchall()
    conn.close()
    return rows


@app.get("/orders/{order_id}", response_model=OrderOut)
def get_order(order_id: int):
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT id, customer_name, product, status FROM orders WHERE id = %s;", (order_id,))
        row = cur.fetchone()
    conn.close()
    if not row:
        raise HTTPException(status_code=404, detail="Commande introuvable")
    return row


@app.get("/dashboard", response_class=HTMLResponse)
def dashboard():
    """Page de visualisation des données métier (constat visuel en fin de projet)."""
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT status, COUNT(*) AS n FROM orders GROUP BY status;")
        by_status = cur.fetchall()
        cur.execute("SELECT id, customer_name, product, status, created_at FROM orders ORDER BY id DESC LIMIT 20;")
        recent = cur.fetchall()
    conn.close()
    labels = [r["status"] for r in by_status]
    values = [r["n"] for r in by_status]
    rows_html = "".join(
        f"<tr><td>{r['id']}</td><td>{r['customer_name']}</td><td>{r['product']}</td>"
        f"<td>{r['status']}</td><td>{r['created_at']}</td></tr>" for r in recent
    )
    return f"""
    <html>
    <head>
      <title>TechCorp Order Tracker — Dashboard</title>
      <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
      <style>
        body {{ font-family: sans-serif; margin: 2rem; background:#f5f6f8; }}
        table {{ border-collapse: collapse; width: 100%; margin-top: 1rem; background:#fff; }}
        th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        th {{ background: #2c3e50; color: white; }}
        h1 {{ color: #2c3e50; }}
        .card {{ background:#fff; padding:1rem; border-radius:8px; box-shadow:0 1px 3px rgba(0,0,0,.1); max-width:400px; }}
      </style>
    </head>
    <body>
      <h1>TechCorp Order Tracker — Tableau de bord</h1>
      <div class="card"><canvas id="statusChart"></canvas></div>
      <h2>20 dernières commandes</h2>
      <table><tr><th>ID</th><th>Client</th><th>Produit</th><th>Statut</th><th>Créée le</th></tr>{rows_html}</table>
      <script>
        new Chart(document.getElementById('statusChart'), {{
          type: 'doughnut',
          data: {{ labels: {labels}, datasets: [{{ data: {values}, backgroundColor: ['#2ecc71','#f1c40f','#e74c3c','#3498db','#9b59b6'] }}] }},
          options: {{ plugins: {{ title: {{ display: true, text: 'Répartition des commandes par statut' }} }} }}
        }});
      </script>
    </body>
    </html>
    """
