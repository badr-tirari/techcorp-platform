# Runbook — déploiement du projet unifié techcorp-platform

A exécuter dans WSL2 (Ubuntu). Coche chaque capture d'écran au fur et à mesure :
elles alimenteront directement le dossier de projet (40-50 pages).

## 0. Pré-requis (une seule fois)

```bash
# AWS CLI (déjà fait normalement)
aws sts get-caller-identity

# Terraform
sudo apt update && sudo apt install -y terraform    # ou méthode habituelle

# Ansible
sudo apt install -y ansible
ansible-galaxy collection install -r ansible/requirements.yml

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Clé SSH (si pas déjà fait)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Ton IP publique actuelle, pour restreindre SSH/Grafana
curl -s ifconfig.me
```

☐ **Capture 1** : sortie de `aws sts get-caller-identity` (preuve d'accès au compte AWS).

## 1. Provisionner l'infrastructure (CCP1 — Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# éditer terraform.tfvars : mettre TON_IP/32 dans allowed_ssh_cidr

terraform init
terraform plan
terraform apply    # taper "yes"
```

☐ **Capture 2** : sortie de `terraform plan` (liste des ressources à créer).
☐ **Capture 3** : sortie de `terraform apply` terminée (outputs : `public_ip`, `app_url`, `grafana_url`).
☐ **Capture 4** (optionnel, alternative script) : sortie de `../scripts/create_server.sh`.

Note coût : `m7i-flex.large` (éligible plan gratuit AWS) en eu-north-1. Pense à `terraform destroy` en
fin de travail (section 8).

## 2. Sécuriser le serveur + installer la plateforme (CCP1 — Ansible)

```bash
cd ../ansible
cp inventory.ini.example inventory.ini
# éditer inventory.ini : remplacer l'IP par le "public_ip" de terraform output

ansible-playbook -i inventory.ini harden.yml
ansible-playbook -i inventory.ini bootstrap_k3s.yml
```

☐ **Capture 5** : sortie de `ansible-playbook harden.yml` (PLAY RECAP, aucun failed).
☐ **Capture 6** : sortie de `ansible-playbook bootstrap_k3s.yml`.

```bash
export KUBECONFIG=$(pwd)/../kubeconfig.yaml
kubectl get nodes
```

☐ **Capture 7** : `kubectl get nodes` → le nœud en état `Ready`.

## 3. Tester l'application en local avant mise en production (CCP2)

```bash
cd ..
docker compose -f docker-compose.test.yml up -d --build
pip install pytest requests
pytest tests/ -v
docker compose -f docker-compose.test.yml down -v
```

☐ **Capture 8** : tous les tests `pytest` passés (5 tests en vert).

## 4. Premier déploiement manuel sur k3s (avant d'activer la CI/CD)

```bash
export KUBECONFIG=$(pwd)/kubeconfig.yaml

kubectl apply -f k8s/00-namespace.yaml
cp k8s/01-postgres-secret.yaml.example k8s/01-postgres-secret.yaml
# éditer k8s/01-postgres-secret.yaml : remplacer les valeurs base64 par les tiennes
#   echo -n 'ton_mot_de_passe' | base64
kubectl apply -f k8s/

kubectl get pods -n techcorp-orders
kubectl get ingress -n techcorp-orders
```

☐ **Capture 9** : `kubectl get pods -n techcorp-orders` (order-tracker x2 + postgres, tous `Running`).
☐ **Capture 10** : `curl http://<IP_PUBLIQUE>/health` → `{"status":"ok",...}`.

## 5. Activer la CI/CD (CCP2)

```bash
git init && git add . && git commit -m "Initial commit — techcorp-platform"
git remote add origin https://github.com/<TON_COMPTE>/techcorp-platform.git
git push -u origin main
```

Sur GitHub : Settings → Secrets and variables → Actions → New repository secret :
- `KUBECONFIG_B64` = sortie de `base64 -w0 kubeconfig.yaml`

Modifie `k8s/04-app-deployment.yaml` : remplace `ghcr.io/OWNER/...` par ton pseudo GitHub.
Refais un `git commit` + `git push` : le workflow se déclenche automatiquement.

☐ **Capture 11** : onglet "Actions" GitHub, run vert (test → build-and-push → deploy).
☐ **Capture 12** : `kubectl rollout status deployment/order-tracker -n techcorp-orders` → rolling update réussi.

## 6. Visualisation des données métier (CCP2)

```bash
curl -X POST http://<IP_PUBLIQUE>/orders -H "Content-Type: application/json" \
  -d '{"customer_name":"Jean Dupont","product":"Formation DevOps","status":"pending"}'
```
Ouvrir `http://<IP_PUBLIQUE>/dashboard` dans un navigateur.

☐ **Capture 13** : la page `/dashboard` avec le graphique en anneau des commandes.

## 7. Déployer et démontrer la supervision (CCP3)

```bash
cd monitoring
cp alertmanager/alertmanager-configmap.yaml.example alertmanager/alertmanager-configmap.yaml
# éditer : renseigner <SMTP_HOST>/<SMTP_USER>/<SMTP_PASSWORD>
#   (ex: smtp.gmail.com + adresse Gmail + mot de passe d'application)
./deploy.sh
```

☐ **Capture 14** : `kubectl get pods -n monitoring` (prometheus, alertmanager, grafana `Running`).

Ouvrir `http://<IP_PUBLIQUE>:3000` (admin / changeme123), ajouter le dashboard.

☐ **Capture 15** : dashboard Grafana en fonctionnement normal (tous les indicateurs sous le seuil).

### Scénario d'incident contrôlé

```bash
# Simuler une panne : couper temporairement postgres
kubectl scale deployment/postgres -n techcorp-orders --replicas=0
```

Attendre 1-2 minutes, rafraîchir Grafana et Alertmanager.

☐ **Capture 16** : dashboard Grafana montrant le dépassement de seuil (courbe rouge / stat en erreur).
☐ **Capture 17** : `http://<IP_PUBLIQUE>:3000` (ou `kubectl get pods -n monitoring` + UI Alertmanager en port-forward) montrant l'alerte `firing`.
☐ **Capture 18** : email d'alerte reçu dans la boîte mail.

### Retour à la normale

```bash
kubectl scale deployment/postgres -n techcorp-orders --replicas=1
```

☐ **Capture 19** : dashboard Grafana revenu à la normale + alerte `resolved`.

## 8. Nettoyage (fin de la démonstration)

```bash
cd ../terraform
terraform destroy   # taper "yes" — arrête la facturation AWS
```

☐ **Capture 20** : confirmation `terraform destroy` terminé.

---

Une fois ces captures en main, envoie-les moi (ou dis-moi lesquelles tu as) : je les
intègre directement dans le dossier de projet et le support de présentation.
