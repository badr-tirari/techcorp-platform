#!/usr/bin/env bash
# Déploie toute la stack de supervision CCP3 (Prometheus + Alertmanager + Grafana)
# sur le cluster k3s. A exécuter après avoir déployé l'application (k8s/).
set -euo pipefail
cd "$(dirname "$0")"

kubectl apply -f 00-namespace.yaml

# --- Prometheus (config + alert rules) ---
kubectl apply -f prometheus/prometheus-configmap.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml

# --- Alertmanager ---
if [ ! -f alertmanager/alertmanager-configmap.yaml ]; then
  echo "ERREUR: copie alertmanager/alertmanager-configmap.yaml.example vers alertmanager-configmap.yaml"
  echo "        et renseigne <SMTP_HOST>/<SMTP_USER>/<SMTP_PASSWORD> avant de continuer."
  exit 1
fi
kubectl apply -f alertmanager/alertmanager-configmap.yaml
kubectl apply -f alertmanager/alertmanager-deployment.yaml

# --- Grafana : datasource + provisioning + dashboard, générés depuis les fichiers ---
kubectl create configmap grafana-datasources \
  --from-file=grafana/provisioning/datasources/prometheus.yaml \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap grafana-dashboard-provider \
  --from-file=grafana/provisioning/dashboards/dashboard.yaml \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap grafana-dashboards \
  --from-file=grafana/dashboards/order-tracker-dashboard.json \
  -n monitoring --dry-run=client -o yaml | kubectl apply -f -

if [ ! -f grafana/grafana-secret.yaml ]; then
  echo "ERREUR: copie grafana/grafana-secret.yaml.example vers grafana-secret.yaml et definis le mot de passe admin."
  exit 1
fi
kubectl apply -f grafana/grafana-secret.yaml

kubectl apply -f grafana/grafana-deployment.yaml

echo "Stack de supervision déployée. kubectl get pods -n monitoring"
echo "Grafana : http://<IP_PUBLIQUE>:3000 (admin / mot de passe defini dans grafana-secret.yaml)"
