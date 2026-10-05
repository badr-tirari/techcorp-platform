# techcorp-platform

Projet unique servant de support aux **3 CCP du Titre Professionnel Administrateur
Système DevOps** (Bachelor DevOps, Studi) :

| CCP | Compétence | Ce qui la démontre dans ce projet |
|---|---|---|
| **CCP1** | Automatiser le déploiement d'une infrastructure dans le cloud | `terraform/` (VPC, EC2, sécurité réseau) + `ansible/harden.yml` (durcissement ANSSI) + `ansible/bootstrap_k3s.yml` (plateforme de prod) |
| **CCP2** | Déployer en continu une application | `app/` (FastAPI + Postgres) + `tests/` + `.github/workflows/deploy.yml` (CI/CD) + `k8s/` (déploiement K8s, rolling update) |
| **CCP3** | Superviser les services déployés | `monitoring/` (Prometheus, règles d'alerte SLA, Alertmanager, dashboard Grafana) |

C'est **une seule infrastructure, une seule application, un seul pipeline** :
Terraform+Ansible provisionnent et sécurisent un serveur AWS et y installent une
plateforme Kubernetes légère (k3s) ; la CI/CD GitHub Actions y déploie en continu
l'application TechCorp Order Tracker ; Prometheus/Grafana/Alertmanager supervisent
cette même application et remontent une alerte par email en cas de dépassement de
seuil SLA.

## Démarrage

Voir **RUNBOOK.md** pour la procédure complète, étape par étape, avec la liste des
captures d'écran à conserver pour le dossier de projet.

## Architecture

```
                         Internet
                            │
                    [Terraform : VPC, IGW, SG]
                            │
                 ┌──────────────────────┐
                 │  EC2 (Ubuntu 22.04)  │ <- Ansible : durcissement + k3s
                 │  ┌─────────────────┐ │
                 │  │  k3s (K8s)      │ │
                 │  │                 │ │
                 │  │ ns techcorp-    │ │  <- CI/CD (CCP2) déploie ici
                 │  │  orders:        │ │
                 │  │  - order-tracker│ │
                 │  │    (2 replicas) │ │
                 │  │  - postgres     │ │
                 │  │                 │ │
                 │  │ ns monitoring:  │ │  <- Supervision (CCP3)
                 │  │  - prometheus   │ │
                 │  │  - alertmanager │ │
                 │  │  - grafana      │ │
                 │  └─────────────────┘ │
                 └──────────────────────┘
```
