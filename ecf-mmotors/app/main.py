"""M-Motors API — application FastAPI (Activité Type 2, question 1).

- GET /         : Hello World
- GET /health   : sonde de santé utilisée par l'ALB et ECS
- GET /dossiers/{dossier_id}/documents : liste les pièces d'un dossier
  d'achat/location stockées dans le bucket S3 privé (lecture seule, via le
  rôle IAM de la tâche ECS — aucune clé dans le code).
"""

import logging
import os
import re

from fastapi import FastAPI, HTTPException

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger("mmotors.api")

app = FastAPI(title="M-Motors API", version="1.0.0")

DOSSIER_ID = re.compile(r"^[A-Za-z0-9-]{1,64}$")


@app.get("/")
def hello_world() -> dict:
    return {"message": "Hello World"}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/dossiers/{dossier_id}/documents")
def list_documents(dossier_id: str) -> dict:
    if not DOSSIER_ID.match(dossier_id):
        raise HTTPException(status_code=400, detail="Identifiant de dossier invalide")

    bucket = os.getenv("DOCUMENTS_BUCKET")
    if not bucket:
        raise HTTPException(status_code=503, detail="Stockage des dossiers non configuré")

    import boto3  # import tardif : inutile pour les tests unitaires

    prefix = f"dossiers/{dossier_id}/"
    try:
        response = boto3.client("s3").list_objects_v2(Bucket=bucket, Prefix=prefix)
    except Exception:
        logger.exception("ERROR lecture S3 impossible pour le dossier %s", dossier_id)
        raise HTTPException(status_code=502, detail="Lecture des documents impossible")

    documents = [
        {"nom": obj["Key"][len(prefix):], "taille": obj["Size"]}
        for obj in response.get("Contents", [])
    ]
    return {"dossier": dossier_id, "documents": documents}
