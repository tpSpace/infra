# Complete Thesis Infrastructure & GitOps Guide

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Infrastructure Setup](#infrastructure-setup)
4. [ArgoCD Multi-Repository GitOps](#argocd-multi-repository-gitops)
5. [Auto Sync Configuration](#auto-sync-configuration)
6. [Image Update Strategies](#image-update-strategies)
7. [Deployment Instructions](#deployment-instructions)
8. [Troubleshooting](#troubleshooting)
9. [Useful Commands](#useful-commands)

---

## Overview

This repository contains the complete infrastructure configuration for the thesis project, implementing GitOps principles with ArgoCD for automated deployment of frontend and backend services.

### Services

- **Backend Service**: Node.js application exposed on port 4000
- **Frontend Service**: Next.js application exposed on port 80 (via port 3000)
- **PostgreSQL Database**: Persistent database with initialization scripts
- **RabbitMQ**: Message queue service
- **ArgoCD**: GitOps continuous deployment
- **Prometheus & Grafana**: Monitoring and observability

### Repository Structure

```bash
├── main.tf                           # Main Terraform infrastructure
├── variables.tf                      # Terraform variables
├── terraform.tfvars                  # Terraform values
├── configmap.yaml                    # Shared application configuration
├── secret.yaml                       # Database credentials
├── postgres-init-configmap.yaml      # Database initialization
├── statefulset-db.yaml               # PostgreSQL database
├── ingress.yaml                      # Traffic routing
├── thesis-project.yaml               # ArgoCD project configuration
├── argocd-fe-repo-config.yaml        # Frontend repository SSH access
├── argocd-be-repo-config.yaml        # Backend repository SSH access
├── setup-multi-repo-argocd.sh        # Setup automation script
├── fe/
│   ├── frontend-application.yaml     # ArgoCD frontend application
│   └── runtime-config-setup.md       # Frontend runtime configuration guide
└── be/backend-application.yaml       # ArgoCD backend application
```

---

## Architecture

### Infrastructure Management

- **Terraform**: Manages GKE cluster, ArgoCD installation, databases, message queues
- **ArgoCD**: Manages application deployments from source repositories

### GitOps Flow

```bash
Developer → Push Code → GitHub → ArgoCD → Kubernetes → Application Update
```

### Repository Strategy

- **thesis-fe**: Frontend code + K8s manifests in `/k8s/`
- **thesis-be**: Backend code + K8s manifests in `/k8s/`
- **infra**: Infrastructure code (this repository)

---

## Infrastructure Setup

### Prerequisites

1. Google Cloud Platform project
2. Service account with Kubernetes Engine Admin permissions
3. `gcloud`, `kubectl`, `terraform` installed
4. GitHub repositories with appropriate access

### Initial Deployment

1. **Prepare credentials**

   ```bash
   # Download service account credentials.json to this directory
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Deploy infrastructure**

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Get cluster credentials**

   ```bash
   gcloud container clusters get-credentials thesis-cluster --region us-central1
   ```

4. **Setup ArgoCD multi-repository access**

   ```bash
   ./setup-multi-repo-argocd.sh
   ```

---

## ArgoCD Multi-Repository GitOps

### Architecture Benefits

✅ **True GitOps**: Code and infrastructure in same repos  
✅ **Independent Deployments**: FE and BE deploy separately  
✅ **Developer-Friendly**: Developers control deployment configs  
✅ **No Resource Conflicts**: Clear ownership boundaries  

### Repository Configuration

#### SSH Keys Setup

Each repository requires its own SSH deploy key:

**Frontend Repository** (`thesis-fe`)

- SSH Key: Generated in `argocd-fe` (private) / `argocd-fe.pub` (public)
- Add public key to: `https://github.com/tpSpace/thesis-fe/settings/keys`

**Backend Repository** (`thesis-be`)

- SSH Key: Generated in `argocd-be` (private) / `argocd-be.pub` (public)  
- Add public key to: `https://github.com/tpSpace/thesis-be/settings/keys`

#### Application Repository Structure

```bash
thesis-fe/
├── src/                    # Frontend application code
├── k8s/                    # Kubernetes manifests
│   ├── deployment.yaml     # Frontend deployment
│   └── service.yaml        # Frontend service
└── ...

thesis-be/
├── src/                    # Backend application code
├── k8s/                    # Kubernetes manifests
│   ├── deployment.yaml     # Backend deployment
│   └── service.yaml        # Backend service
└── ...
```

### ArgoCD Configuration Files

#### Project Configuration (`thesis-project.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: thesis
spec:
  sourceRepos:
    - git@github.com:tpSpace/infra.git
    - git@github.com:tpSpace/thesis-fe.git
    - git@github.com:tpSpace/thesis-be.git
```

#### Application Configuration

- **Frontend**: Watches `thesis-fe/k8s/` directory
- **Backend**: Watches `thesis-be/k8s/` directory

---

## Auto Sync Configuration

### Current Auto Sync Features

Your ArgoCD applications have auto sync enabled with:

✅ **Polling**: Checks for changes every 3 minutes  
✅ **Auto Prune**: Removes deleted resources  
✅ **Self Heal**: Fixes configuration drift  
✅ **Retry Logic**: Automatically retries failed syncs  

### Sync Policy Configuration

```yaml
syncPolicy:
  automated:
    prune: true        # Automatically delete resources no longer in Git
    selfHeal: true     # Automatically fix drift from desired state
    allowEmpty: false  # Don't sync if no resources found
  syncOptions:
    - CreateNamespace=false
    - PruneLast=true
    - ApplyOutOfSyncOnly=true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

### Webhook Setup for Instant Sync

**ArgoCD Webhook URL**: `http://34.92.178.198/api/webhook`

Add to GitHub repositories:

1. Go to repository → Settings → Webhooks
2. Add webhook with above URL
3. Select "Just the push event"
4. Content type: `application/json`

### Manual Sync Options

```bash
# Via ArgoCD CLI
argocd app sync thesis-frontend
argocd app sync thesis-backend

# Via kubectl (force refresh)
kubectl patch application thesis-frontend -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' --type merge
```

---

## Image Update Strategies

### The Challenge

ArgoCD syncs manifests but doesn't deploy new versions when using `:latest` tags because:

- Using `:latest` tag doesn't trigger pod updates
- Kubernetes sees same manifest = no changes needed
- Need manifest changes to trigger deployment

### Solution 1: Version Tags + imagePullPolicy (Current)

```yaml
spec:
  containers:
    - name: frontend
      image: ghcr.io/tpspace/thesis-fe:latest
      imagePullPolicy: Always  # Always pull the image
```

### Solution 2: Automated CI/CD with GitHub Actions

#### Frontend Workflow (`.github/workflows/deploy-fe.yml`)

```yaml
name: Build and Deploy Frontend
on:
  push:
    branches: [main]
    paths: ['src/**', 'package.json', 'dockerfile']

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Build and push image
      # Build with commit SHA tag
    - name: Update K8s manifest
      run: |
        # Update deployment.yaml with new image tag
        # Commit changes back to repo
```

#### Backend Workflow (`.github/workflows/deploy-be.yml`)

```yaml
name: Build and Deploy Backend
on:
  push:
    branches: [main] 
    paths: ['src/**', 'package.json', 'Dockerfile']
# Similar structure to frontend workflow
```

### Deployment Flow

1. Developer pushes code to main branch
2. GitHub Actions builds Docker image with commit SHA tag
3. Updates K8s deployment manifest with new image tag
4. Commits manifest change back to repo
5. ArgoCD detects manifest change and deploys new version

---

## Deployment Instructions

### ArgoCD Access

```bash
# Get ArgoCD server details
kubectl get svc -n argocd argocd-server

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Application Deployment Status

```bash
# Check application status
kubectl get applications -n argocd

# Check detailed status
kubectl describe application thesis-frontend -n argocd
kubectl describe application thesis-backend -n argocd
```

### Service Endpoints

```bash
# Get all services and external IPs
kubectl get svc --all-namespaces -o wide

# Access applications via LoadBalancer
# Frontend: http://<EXTERNAL_IP>/app
# Backend: http://<EXTERNAL_IP>/api
# ArgoCD: http://<ARGOCD_IP>
# Grafana: http://<GRAFANA_IP>:9999
# Prometheus: http://<PROMETHEUS_IP>
```

---

## Troubleshooting

### Common Issues

#### 1. Repository Access Problems

```bash
# Check SSH keys are added to GitHub
# Verify repository URLs are correct
kubectl logs -n argocd deployment/argocd-repo-server
```

#### 2. Applications Not Syncing

```bash
# Check ArgoCD UI for sync status
# Verify K8s manifests are valid YAML
kubectl get events -n argocd --field-selector involvedObject.name=thesis-frontend
```

#### 3. Images Not Updating

- Check `imagePullPolicy: Always` is set
- Verify image tags are changing
- Force pod restart if needed:

```bash
kubectl rollout restart deployment/frontend -n my-thesis
kubectl rollout restart deployment/backend -n my-thesis
```

#### 4. Resource Conflicts

- Ensure Terraform doesn't manage resources that ArgoCD manages
- Check for duplicate resource definitions

#### 5. Frontend Environment Configuration Issues

- For Next.js runtime configuration issues, see: [fe/runtime-config-setup.md](./fe/runtime-config-setup.md)
- Verify `window.__RUNTIME_CONFIG__` in browser console
- Check that environment variables are properly injected at container startup

### Debug Commands

```bash
# ArgoCD logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-repo-server

# Application logs
kubectl logs -n my-thesis deployment/frontend
kubectl logs -n my-thesis deployment/backend

# Check pod status
kubectl get pods -n my-thesis -o wide
kubectl describe pod <pod-name> -n my-thesis
```

---

## Useful Commands

### Kubernetes Operations

```bash
# Get all pods in thesis namespace
kubectl get pods -n my-thesis

# Get pods with detailed info
kubectl get pods -n my-thesis -o wide

# Execute into pod
kubectl exec -it <pod-name> -n my-thesis -- sh

# Check pod logs
kubectl logs <pod-name> -n my-thesis -f

# Restart deployments
kubectl rollout restart deployment frontend -n my-thesis
kubectl rollout restart deployment backend -n my-thesis
```

### Database Operations

```bash
# Connect to PostgreSQL
kubectl exec -it <postgres-pod> -n my-thesis -- psql -U postgres

# Check database connection
kubectl port-forward svc/postgres-headless 5432:5432 -n my-thesis
```

### ArgoCD Operations

```bash
# Restart ArgoCD components
kubectl rollout restart deployment -l app.kubernetes.io/part-of=argocd -n argocd

# Check ArgoCD applications
kubectl get applications -n argocd

# Force application sync
kubectl patch application thesis-frontend -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' --type merge
```

### Terraform Operations

```bash
# Plan infrastructure changes
terraform plan

# Apply infrastructure changes
terraform apply

# Target specific resources
terraform apply -target=google_container_cluster.gke

# Destroy infrastructure (be careful!)
terraform destroy
```

### Monitoring

```bash
# Check service external IPs
kubectl get svc --all-namespaces | grep LoadBalancer

# Check ingress status
kubectl get ingress -n my-thesis

# Monitor resource usage
kubectl top pods -n my-thesis
kubectl top nodes
```

---

## Best Practices

### GitOps

✅ Use specific image tags (not `:latest`) for production  
✅ Set `imagePullPolicy: Always` for development  
✅ Automate image tag updates with CI/CD  
✅ Use commit SHAs for traceability  
✅ Monitor deployment status in ArgoCD UI  
✅ Test changes in staging before production  

### Security

✅ Use separate SSH keys for each repository  
✅ Rotate SSH keys regularly  
✅ Use secrets for sensitive configuration  
✅ Implement RBAC for ArgoCD access  
✅ Monitor for configuration drift  

### Operations

✅ Monitor application health and performance  
✅ Set up alerting for failed deployments  
✅ Regularly backup configuration and data  
✅ Document all manual interventions  
✅ Keep infrastructure code in version control  

---

## Support

For issues or questions:

1. Check ArgoCD UI for application status
2. Review logs using the debug commands above
3. Verify configuration against this documentation
4. Check GitHub repository access and SSH keys

This guide represents the complete setup for a GitOps-based thesis infrastructure with automated deployment capabilities. 🚀
