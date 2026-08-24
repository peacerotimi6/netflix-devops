# Netflix-Style Video Streaming Webapp

A full-stack Netflix clone built with **React 18 + TypeScript + Material-UI**, powered by the TMDB API.
Backed by a complete **DevSecOps pipeline** on Azure: Terraform IaC, GitHub Actions CI/CD,
AKS with multi-zone node pools, **Azure Front Door + WAF** global edge, **Blue/Green deployments via Argo Rollouts**,
ACR and Key Vault on **Private Endpoints**, and automated TLS via cert-manager. Live at **adedayo.shop**.

![Home Page](app/public/assets/home-page.png)

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Environment Comparison (Dev vs Prod)](#environment-comparison-dev-vs-prod)
- [CI/CD Pipelines](#cicd-pipelines)
- [Security Layers](#security-layers)
- [Monitoring & Observability](#monitoring--observability)
- [Getting Started](#getting-started)
- [Documentation](#documentation)

---

## Features

### Application
- Netflix-style UI — hero section, genre carousels, infinite scroll, detail modals
- Movies & TV shows via **TMDB API** (v3)
- Video playback with **VideoJS** + YouTube plugin
- Fully responsive design (mobile, tablet, desktop)
- **FastAPI** backend with **Sentence Transformers** ML embeddings for similarity search

### Infrastructure & DevOps
- **Modular Terraform** IaC on Azure (AKS, ACR, Key Vault, Front Door, custom VNet)
- **Azure Front Door Standard** — global CDN edge with TLS termination and HTTPS redirect
- **Multi-zone AKS node pools** — system pool (zone 1) + app pool (zone 2) for high availability
- **Custom VNet** with 4 segmented subnets: system, app, ingress, and private endpoints
- **Azure CNI** networking with Azure Network Policy enforcement
- **NSG**: port 443 restricted to `AzureFrontDoor.Backend` service tag — prevents LB bypass
- **OIDC/Workload Identity Federation** — no long-lived secrets stored anywhere
- **Argo Rollouts Blue/Green** — zero-downtime releases with manual promotion gate and instant rollback
- **cert-manager** + Let's Encrypt automatic TLS for `adedayo.shop` and `www.adedayo.shop`
- **Helm-managed monitoring** via `kube-prometheus-stack` on the App Node Pool

### Security
- **WAF Policy (Prevention Mode)** — DefaultRuleSet 1.0 (OWASP Top 10) + BotManagerRuleSet 1.0 at AFD edge
- **ACR Private Endpoint** — Premium SKU, public network access disabled, resolves via `privatelink.azurecr.io`
- **Key Vault Private Endpoint** — public network access disabled, resolves via `privatelink.vaultcore.azure.net`
- **Trivy** — container image and filesystem CVE scanning
- **SonarCloud** — SAST quality gate (blocks deploy on failure)
- **Checkov** — IaC security scanning (Terraform + Kubernetes manifests → GitHub Security tab)
- **OWASP ZAP** — dynamic application security testing (DAST) on production
- **Kubernetes Network Policies** — deny-all default, allow-list per service
- **Non-root containers** — all pods run as UID 10001, port 8080
- **RBAC** throughout — Key Vault Secrets User, AcrPull via managed identity
- **PodDisruptionBudget** on production — `minAvailable: 2`

---

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| **Frontend** | React 18, TypeScript, Material-UI v5, Redux Toolkit, RTK Query, Vite, Framer Motion, VideoJS |
| **Backend** | FastAPI, Python 3.10, Sentence Transformers (all-MiniLM-L6-v2) |
| **Containers** | Docker (multi-stage), Nginx 1.25 Alpine (port 8080, non-root) |
| **Orchestration** | Kubernetes 1.33 on AKS, Helm 3, Argo Rollouts |
| **Edge / CDN** | Azure Front Door Standard, WAF Policy (Prevention Mode) |
| **Networking** | Azure CNI, Azure Network Policy, custom VNet, NSGs, Nginx Ingress Controller |
| **TLS** | cert-manager, Let's Encrypt ACME HTTP-01 |
| **Infrastructure** | Terraform ~> 4.0 (azurerm), AKS, ACR (Premium), Key Vault, Log Analytics, Front Door |
| **Private Connectivity** | ACR Private Endpoint, Key Vault Private Endpoint, Private DNS Zones |
| **CI/CD** | GitHub Actions (5 workflows), OIDC federation |
| **Deployments** | Argo Rollouts — Blue/Green strategy, manual promotion, 60s blue scale-down |
| **Security** | Trivy, SonarCloud, Checkov, OWASP ZAP, WAF, RBAC, Network Policies |
| **Monitoring** | kube-prometheus-stack (Prometheus, Grafana, Alertmanager, kube-state-metrics) |
| **DNS** | GoDaddy — adedayo.shop (CNAME → Azure Front Door) |

---

## Architecture Overview

### Production Traffic Flow

```
Users
  │
  ├── DNS lookup → GoDaddy (adedayo.shop)
  │                  CNAME → Azure Front Door endpoint
  │
  ▼
┌─────────────────────────────────────────────────────┐
│  Azure Front Door Standard  —  Global CDN Edge       │
│  TLS termination  ·  AFD-managed certificates        │
│  HTTPS redirect (HTTP → 308)                         │
│                                                      │
│  ┌─────────────────────────────────────────────┐    │
│  │  WAF Policy  (Prevention Mode)               │    │
│  │  DefaultRuleSet 1.0  — OWASP Top 10          │    │
│  │  BotManagerRuleSet 1.0  — bot protection     │    │
│  └─────────────────────────────────────────────┘    │
└──────────────────────────┬──────────────────────────┘
                           │ HTTPS  (AzureFrontDoor.Backend)
                           ▼
┌─────────────────────────────────────────────────────┐
│  NSG  —  Azure Virtual Network  (10.1.0.0/16)       │
│  Port 443: AzureFrontDoor.Backend only               │
│  Port 80:  Internet  (ACME HTTP-01 cert renewals)   │
│                                                      │
│  Azure Standard Load Balancer  (128.203.69.104)      │
│  Auto-provisioned by AKS CCM  ·  TCP health probe   │
└──────────────────────────┬──────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────────┐
│  AKS Subnet  (Azure CNI + Network Policy)                            │
│                                                                      │
│  ┌────────────────────────────┐  ┌──────────────────────────────┐   │
│  │  System Node Pool (Zone 1) │  │  App Node Pool (Zone 2)      │   │
│  │  Taint: CriticalAddonsOnly │  │  Autoscale 2→6  (no taints)  │   │
│  │                            │  │                              │   │
│  │  ingress-nginx  (2 pods)   │  │  argo-rollouts namespace     │   │
│  │  cert-manager              │  │  ┌──────────────────────┐   │   │
│  │                            │  │  │ Argo Rollouts Ctrl   │   │   │
│  └────────────────────────────┘  │  └──────────────────────┘   │   │
│                                  │                              │   │
│                                  │  netflix-prod namespace      │   │
│                                  │  ┌──────────────────────┐   │   │
│                                  │  │ netflix-web (B/G)     │   │   │
│                                  │  │  active ← ingress     │   │   │
│                                  │  │  preview ← smoke test │   │   │
│                                  │  │ netflix-api (B/G)     │   │   │
│                                  │  │  active ← ingress     │   │   │
│                                  │  │  preview ← smoke test │   │   │
│                                  │  │ HPA · PDB · Ingress   │   │   │
│                                  │  └──────────────────────┘   │   │
│                                  │                              │   │
│                                  │  monitoring namespace        │   │
│                                  │  ┌──────────────────────┐   │   │
│                                  │  │ Prometheus (15s/15d)  │   │   │
│                                  │  │ Grafana (ops access)  │   │   │
│                                  │  │ Alertmanager          │   │   │
│                                  │  │ kube-state-metrics    │   │   │
│                                  │  └──────────────────────┘   │   │
│                                  └──────────────────────────────┘   │
└──────────────────────────────┬──────────────────────────────────────┘
                               │  Private Endpoint Subnet (10.1.4.0/24)
              ┌────────────────┴─────────────────┐
              ▼                                   ▼
┌─────────────────────────┐          ┌─────────────────────────┐
│  Azure Container         │          │  Azure Key Vault         │
│  Registry (Premium SKU) │          │  🔒 Private Endpoint     │
│  🔒 Private Endpoint    │          │  public access disabled  │
│  public access disabled │          │  Secrets User RBAC       │
│  AcrPull managed identity│         └─────────────────────────┘
└─────────────────────────┘
```

### Argo Rollouts — Blue/Green Flow

```
CI/CD pushes new image tag → Argo Rollouts Controller detects spec change
  │
  ├── spins up green replica set (preview replicas)
  ├── patches netflix-web-preview / netflix-api-preview selectors → green pods
  ├── smoke test runs against preview service
  │
  ├── engineer runs: kubectl argo rollouts promote netflix-web -n netflix-prod
  │
  ├── patches netflix-web-active selector → green pods  (zero-downtime flip)
  └── scales down blue replica set after 60 seconds
```

### VNet Network Segmentation

```
Azure VNet  (Prod: 10.1.0.0/16)
├── aks-system subnet    (10.1.1.0/24)  Zone 1 — system node pool
├── aks-app    subnet    (10.1.2.0/24)  Zone 2 — app node pool
├── ingress    subnet    (10.1.3.0/24)  Load Balancer frontend
└── private-endpoints    (10.1.4.0/24)  ACR PE + Key Vault PE
                                         private_endpoint_network_policies=Disabled
```

### Terraform Module Graph

```
resource-group
  ├── networking  (VNet, subnets, NSGs, private-endpoint subnet)
  ├── ACR         (Premium SKU, private endpoint, private DNS zone)
  ├── keyvaults   (private endpoint, private DNS zone)
  ├── frontdoor   (AFD Standard profile, WAF policy, custom domains)
  └── AKS         (depends on networking + ACR)
```

---

## Project Structure

```
netflix-streaming-webapp/
│
├── app/                         # Application code
│   ├── src/                     # React TypeScript source
│   │   ├── pages/               # HomePage, GenreExplore, WatchPage
│   │   ├── components/          # 50+ UI components
│   │   ├── store/               # Redux Toolkit + RTK Query (TMDB API)
│   │   ├── hooks/               # Custom hooks (intersection observer, etc.)
│   │   ├── providers/           # React context providers
│   │   ├── layouts/             # MainLayout (header + footer)
│   │   └── theme/               # MUI dark Netflix theme
│   ├── main.py                  # FastAPI backend (ML embeddings)
│   ├── requirements.txt         # Python dependencies
│   ├── Dockerfile               # FastAPI container
│   ├── Dockerfile.frontend      # React multi-stage → Nginx (port 8080)
│   └── nginx.conf               # Non-root Nginx config (port 8080)
│
├── Modules/                     # Terraform module library
│   ├── resource-group/          # Azure Resource Group
│   ├── networking/              # VNet + subnets + NSGs + private-endpoint subnet
│   ├── ACR/                     # Azure Container Registry (Premium, private endpoint)
│   ├── AKS/                     # AKS cluster (multi-zone node pools, OIDC)
│   ├── keyvaults/               # Key Vault + private endpoint + RBAC
│   ├── frontdoor/               # Azure Front Door Standard + WAF policy
│   └── secrets-manager/         # Key Vault secret storage
│
├── environment/                 # Environment-specific Terraform configs
│   ├── dev/                     # Dev: main.tf, variables.tf, terraform.tfvars
│   └── prod/                    # Prod: main.tf, variables.tf, terraform.tfvars
│
├── k8s/                         # Kubernetes manifests
│   ├── base/                    # Shared: namespaces, configmaps, network-policies,
│   │                            #         cert-manager-issuers
│   ├── dev/                     # Dev: deployment, service, ingress, hpa
│   ├── prod/                    # Prod: service, ingress, hpa, pdb
│   │   └── argo-rollouts/       # Rollout CRDs: rollout-web.yml, rollout-api.yml,
│   │                            #               services.yml (active + preview pairs)
│   └── monitoring/              # kube-prometheus-stack Helm values,
│                                #   Netflix custom Grafana dashboard ConfigMap
│
├── .github/
│   ├── workflows/
│   │   ├── ci.yml               # PR: build, TypeScript, Trivy, SonarCloud, Checkov
│   │   ├── deploy-dev.yml       # Auto-deploy to dev on push to main
│   │   ├── deploy-prod.yml      # Manual prod deploy — acr import → approval → Argo Rollouts
│   │   ├── terraform.yml        # Terraform plan / apply / destroy
│   │   └── dast-zap-scan.yml    # OWASP ZAP dynamic security scan
│   └── SECRETS_REQUIRED.md      # All required GitHub secrets
│
├── scripts/
│   ├── setup-env.sh             # Dev/prod environment variables setup
│   ├── setup-env.ps1            # Windows PowerShell version
│   ├── setup-oidc.sh            # One-time OIDC federation setup
│   └── setup-dns.sh             # GoDaddy DNS record configuration
│
└── docs/
    ├── BUILD_GUIDE.md           # Step-by-step full build guide
    ├── ARCHITECTURE.md          # Detailed architecture diagrams
    └── architecture.drawio      # draw.io production architecture diagram
```

---

## Environment Comparison (Dev vs Prod)

| | Dev | Prod |
|---|-----|------|
| **Domain** | `dev.adedayo.shop` | `adedayo.shop` + `www.adedayo.shop` |
| **DNS record** | A record → Ingress LB IP | CNAME → Azure Front Door endpoint |
| **Edge / CDN** | None | Azure Front Door Standard |
| **WAF** | None | Prevention Mode — DefaultRuleSet + BotManagerRuleSet |
| **TLS Issuer** | Let's Encrypt Staging | Let's Encrypt Production (via cert-manager) |
| **ACR SKU** | Basic | **Premium** (required for private endpoint) |
| **ACR access** | Public | **Private Endpoint** — public access disabled |
| **Key Vault access** | Public | **Private Endpoint** — public access disabled |
| **Private endpoint subnet** | None | `10.1.4.0/24` |
| **VNet CIDR** | 10.0.0.0/16 | 10.1.0.0/16 |
| **NSG port 443** | Internet | `AzureFrontDoor.Backend` service tag only |
| **System node pool** | Zone 1, autoscale 1–3 | Zone 1, autoscale 1–3 |
| **App node pool** | Zone 2, autoscale 1–5 | Zone 2, autoscale 2–6 |
| **VM size** | Standard_D2s_v3 | Standard_D2s_v3 |
| **Deployment strategy** | Rolling (standard Deployment) | **Argo Rollouts — Blue/Green** |
| **Web replicas** | 2 | 3 active / 2 preview |
| **API replicas** | 1 | 2 active / 1 preview |
| **HPA (web)** | min 2, max 4 | min 3, max 10 |
| **PDB** | None | `minAvailable: 2` |
| **Security context** | Standard | `runAsUser=10001`, `runAsNonRoot=true`, `seccompProfile=RuntimeDefault` |
| **Key Vault soft-delete** | 90 days | 90 days + purge protection |
| **Log Analytics retention** | 30 days | 90 days |
| **Deploy trigger** | Auto on merge to main | Manual `workflow_dispatch` + approval gate |
| **Trivy exit code** | 0 (report only) | 1 (blocks on CRITICAL) |
| **Ingress-nginx replicas** | 1 | 2 (`externalTrafficPolicy=Local`) |

---

## CI/CD Pipelines

### Workflow Map

```
Pull Request to main
  └── ci.yml ──► TypeScript build → SonarCloud SAST → Trivy FS scan
                 → Trivy image scan → Checkov IaC scan
                 All results → GitHub Security tab (SARIF)

Merge to main (automatic)
  └── deploy-dev.yml ──► SonarCloud gate
                         → docker build + push to dev ACR (git SHA tag)
                         → Trivy scan
                         → helm install ingress-nginx + cert-manager
                         → kubectl apply (dev manifests)
                         → rollout status
                         → email notification

Manual trigger
  └── terraform.yml ──► OIDC login → tf init → Checkov → tf plan
                        (action=apply) → tf apply with approval gate
                        (action=destroy) → tf destroy

  └── deploy-prod.yml ──► validate "deploy-prod" confirmation
                          → SonarCloud gate
                          → az acr import (dev → prod ACR, no rebuild)
                          → Trivy CRITICAL scan (exit-code: 1)
                          → GitHub environment approval gate
                          → helm install ingress-nginx + cert-manager
                          → kubectl apply (prod argo-rollouts manifests)
                          → Argo Rollouts controller manages Blue/Green lifecycle
                          → smoke test against preview service
                          → manual promotion: kubectl argo rollouts promote
                          → email notification

  └── dast-zap-scan.yml ──► OWASP ZAP baseline + full + API scan on production
```

### OIDC Authentication Flow

All workflows authenticate to Azure using **OIDC federated identity** — no client secrets stored:

```
GitHub Actions runner
  → generates OIDC token (signed by github.com)
  → azure/login@v2 exchanges it with Azure AD for a short-lived access token
  → token used by az CLI + terraform (ARM_USE_OIDC=true)
  → no secrets stored in GitHub, no rotation needed
```

Required GitHub secrets (3 total, no passwords):

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | App Registration Client ID |
| `AZURE_TENANT_ID` | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID |

---

## Security Layers

| Layer | Tool / Mechanism | When |
|-------|-----------------|------|
| Global edge filtering | **WAF Policy — Prevention Mode** (AFD) | Runtime — every request |
| SAST | SonarCloud | Every PR + before deploy |
| Container CVE | Trivy (image) | After docker build |
| Filesystem CVE | Trivy (fs) | Every PR |
| IaC security | Checkov (Terraform + K8s) | Every PR + terraform plan |
| Dynamic security | OWASP ZAP | After prod deploy |
| Secret management | OIDC (no secrets) + Key Vault Private Endpoint | Runtime |
| Registry isolation | ACR Private Endpoint — public access disabled | Runtime |
| Vault isolation | Key Vault Private Endpoint — public access disabled | Runtime |
| Network isolation | K8s Network Policies + NSGs + AFD service tag | Runtime |
| Pod security | Non-root (UID 10001), seccompProfile=RuntimeDefault | Runtime |
| Availability | PDB minAvailable=2 (prod) | Runtime |

---

## Monitoring & Observability

Monitoring is deployed via Helm (`kube-prometheus-stack`) into the `monitoring` namespace on the **App Node Pool** (no `CriticalAddonsOnly` toleration required).

**Components included:**
- **Prometheus** — metrics collection, 15s scrape interval, 15-day retention, scrapes across all namespaces
- **Grafana** — dashboards (LoadBalancer service — ops access only, not through public ingress)
- **Alertmanager** — alert routing (Slack / email)
- **kube-state-metrics** — deployment/pod/node state metrics
- **node-exporter** — per-node CPU/memory/disk/network
- **cAdvisor** — container resource usage

**Custom Netflix Dashboard (auto-provisioned):**
- Pod CPU and memory usage
- Available replicas per deployment
- Pod restarts (last 1 hour)
- Container running status
- Network I/O (RX/TX per pod)
- HPA current vs desired replicas

**Access Grafana:**
```bash
kubectl get svc kube-prometheus-stack-grafana -n monitoring
# Open http://<EXTERNAL-IP>  (admin / <GRAFANA_ADMIN_PASSWORD>)
# Navigate to: Dashboards → Netflix Streaming App
```

---

## Getting Started

### Prerequisites

```bash
node --version    # 18+
python --version  # 3.10+
docker version
az version        # Azure CLI 2.50+
terraform version # 1.5+
kubectl version --client
helm version      # 3.12+
gh version        # GitHub CLI 2.30+
```

### Local Development

**Frontend:**
```bash
cd app
cp .env.example .env      # add VITE_APP_TMDB_V3_API_KEY=<your_key>
npm install
npm run dev               # → http://localhost:5173
```

**Backend API:**
```bash
cd app
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload  # → http://localhost:8000
```

**Docker (both services):**
```bash
cd app
docker build -f Dockerfile.frontend \
  --build-arg VITE_APP_TMDB_V3_API_KEY=<key> \
  -t netflix-app:local .
docker run -p 8080:8080 netflix-app:local

docker build -f Dockerfile -t netflix-api:local .
docker run -p 8000:80 netflix-api:local
```

### Full Deployment (summary)

```bash
# 1. Bootstrap Azure state storage (one-time)
source scripts/setup-env.sh dev --setup-backend
source scripts/setup-env.sh prod --setup-backend

# 2. Configure OIDC (one-time)
bash scripts/setup-oidc.sh --repo <owner/repo> --set-secrets

# 3. Add remaining GitHub secrets manually (TMDB_API_KEY, GRAFANA_ADMIN_PASSWORD, etc.)
#    See .github/SECRETS_REQUIRED.md

# 4. Create GitHub environments: dev (no gates) + production (reviewer required)

# 5. Provision infrastructure (prod: includes Front Door, private endpoints)
cd environment/dev && terraform init && terraform apply
cd environment/prod && terraform init && terraform apply

# 6. Install Argo Rollouts controller (prod cluster, one-time)
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# 7. Push to main → deploy-dev.yml triggers automatically

# 8. Deploy monitoring
#    GitHub → Actions → Deploy Monitoring Stack → dev

# 9. Configure DNS (after terraform apply outputs Front Door endpoint hostname)
#    adedayo.shop     → CNAME → <frontdoor_endpoint_hostname>
#    www.rotimi.shop → CNAME → <frontdoor_endpoint_hostname>
#    _dnsauth.adedayo.shop     → TXT → <apex_domain_validation_token>
#    _dnsauth.www.adedayo.shop → TXT → <www_domain_validation_token>

# 10. Promote to prod
#     GitHub → Actions → Deploy to Production → image_tag=<sha7> + confirm_deploy=deploy-prod

# 11. After smoke test passes, promote the Blue/Green rollout
kubectl argo rollouts promote netflix-web -n netflix-prod
kubectl argo rollouts promote netflix-api -n netflix-prod
```

**For full step-by-step instructions, see [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md).**

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md) | Complete build guide: prerequisites → local dev → Azure bootstrap → OIDC → Terraform → CI/CD → Argo Rollouts → DNS/TLS → teardown → troubleshooting |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Detailed architecture diagrams: system overview, VNet topology, CI/CD pipeline, K8s cluster layout, OIDC chain, data flow, secret management, monitoring flow, Terraform dependency graph |
| [docs/architecture.drawio](docs/architecture.drawio) | draw.io production architecture diagram (AFD, WAF, private endpoints, Argo Rollouts Blue/Green) |
| [.github/SECRETS_REQUIRED.md](.github/SECRETS_REQUIRED.md) | All required GitHub secrets with descriptions and OIDC setup instructions |

---

## Screenshots


<img width="797" height="434" alt="image" src="https://github.com/user-attachments/assets/05deef44-56ca-4921-9b90-49ba16280824" />


<img width="814" height="454" alt="image" src="https://github.com/user-attachments/assets/5a145c84-0955-4f15-a831-fa84cdcc3584" />



## License

MIT
