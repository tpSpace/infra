# 🎓 Complete Thesis Project Setup Guide for Newbies

This guide will walk you through setting up the entire thesis project from scratch, including all services, credentials, and infrastructure.

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Repository Structure](#repository-structure)
4. [Step 1: Initial Setup & Tools](#step-1-initial-setup--tools)
5. [Step 2: Clone & Upload Repositories to Your GitHub Account](#step-2-clone--upload-repositories-to-your-github-account)
6. [Step 3: Google Cloud Platform Setup](#step-3-google-cloud-platform-setup)
7. [Step 4: GitHub Container Registry Setup](#step-4-github-container-registry-setup)
8. [Step 5: GitHub Secrets Configuration](#step-5-github-secrets-configuration)
9. [Step 6: Infrastructure Deployment](#step-6-infrastructure-deployment)
10. [Step 7: Database Initialization & Schema Setup](#step-7-database-initialization--schema-setup)
11. [Step 8: Service Deployment](#step-8-service-deployment)
12. [Step 9: Verification & Testing](#step-9-verification--testing)
13. [Troubleshooting](#troubleshooting)
14. [Useful Commands](#useful-commands)

---

## 🏗️ Project Overview

This thesis project implements a **microservices-based automated grading system** with the following architecture:

### Services

- **Frontend (FE)**: Next.js application for student/teacher interface
- **Backend (BE)**: Node.js GraphQL API for core business logic
- **LLM Service**: TypeScript/Bun service for AI-powered code grading using Gemini
- **Tester**: Java Docker image for executing student code tests
- **Sample**: Java sample project for testing purposes

### Infrastructure

- **Google Kubernetes Engine (GKE)**: Container orchestration
- **ArgoCD**: GitOps continuous deployment
- **PostgreSQL**: Primary database + LLM-specific database
- **RabbitMQ**: Message queue for async processing
- **Prometheus & Grafana**: Monitoring and observability
- **Nginx Ingress**: Traffic routing and load balancing

### Repositories

You should have these repositories:

```bash
thesis/
├── config/                 # Infrastructure & Terraform (this repo)
├── be/                     # Backend service
├── fe/                     # Frontend service  
├── thesis-llm/             # LLM grading service
├── thesis-tester/          # Docker image for code testing
└── thesis-sample/          # Sample Java project for testing
```

---

## 🔧 Prerequisites

### Required Accounts

- **Google Cloud Platform** account with billing enabled
- **GitHub** account
- **Google AI Studio** account (for Gemini API key)

### Required Software

```bash
# Install these tools on your local machine:

# 1. Google Cloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud --version

# 2. Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 3. Terraform
wget https://releases.hashicorp.com/terraform/1.11.4/terraform_1.11.4_linux_amd64.zip
unzip terraform_1.11.4_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# 4. Docker (for testing)
sudo apt-get update
sudo apt-get install docker.io
sudo usermod -aG docker $USER

# 5. Git
sudo apt-get install git
```

---

## 📁 Repository Structure

First, understand your repository structure:

```bash
config/                          # Main infrastructure repository
├── main.tf                      # Terraform infrastructure definition
├── variables.tf                 # Terraform variable definitions
├── terraform.tfvars            # Your configuration values
├── configmap.yaml              # Application configuration
├── secret.yaml                 # Database and service secrets
├── be/                         # Backend Kubernetes manifests
│   ├── deployment-backend.yaml
│   ├── service-backend.yaml
│   └── backend-application.yaml
├── fe/                         # Frontend Kubernetes manifests
│   ├── deployment-frontend.yaml
│   ├── service-frontend.yaml
│   └── frontend-application.yaml
├── llm/                        # LLM service ArgoCD application
├── postgres-0/                 # Primary PostgreSQL
├── postgres-1/                 # LLM PostgreSQL
├── rabbitmq/                   # RabbitMQ configuration
└── argocd/                     # ArgoCD configuration
```

---

## 🚀 Step 1: Initial Setup & Tools

### 1.1 Verify Tool Installation

```bash
gcloud --version
kubectl version --client
terraform --version
docker --version
git --version
```

---

## 📥 Step 2: Clone & Upload Repositories to Your GitHub Account

**⚠️ IMPORTANT**: Before setting up infrastructure, you need to clone the original repositories and upload them to your own GitHub account, then verify that GitHub Actions can build and push Docker images successfully.

**Why clone and reupload instead of forking?**

- ✅ **Complete ownership**: No dependency on original repositories
- ✅ **Full control**: You can rename, modify, or delete without restrictions  
- ✅ **Independence**: Original repository changes won't affect your project
- ✅ **Clean history**: Start with a fresh git history under your account

### 2.1 Create New Repositories on GitHub

First, create new empty repositories on your GitHub account:

1. **Go to GitHub and create these repositories** (make them public):
   - `https://github.com/YOUR_USERNAME` → Click "New repository"
   - Create: `config` (for infrastructure)
   - Create: `thesis-be` (for backend)
   - Create: `thesis-fe` (for frontend)
   - Create: `thesis-llm` (for LLM service)
   - Create: `thesis-tester` (for tester image)
   - Create: `thesis-sample` (for sample Java project)

2. **❌ Do NOT initialize with README, .gitignore, or license** - leave them completely empty

### 2.2 Clone Original Repositories and Push to Your Account

```bash
# Create a thesis directory
mkdir -p ~/thesis
cd ~/thesis

# Clone original repositories (replace 'ORIGINAL_OWNER' with the actual GitHub username)
# Example: if the original repos are at https://github.com/tpSpace/config, then ORIGINAL_OWNER = tpSpace
git clone https://github.com/ORIGINAL_OWNER/config.git config-original
git clone https://github.com/ORIGINAL_OWNER/thesis-be.git be-original
git clone https://github.com/ORIGINAL_OWNER/thesis-fe.git fe-original
git clone https://github.com/ORIGINAL_OWNER/thesis-llm.git llm-original
git clone https://github.com/ORIGINAL_OWNER/thesis-tester.git tester-original
git clone https://github.com/ORIGINAL_OWNER/thesis-sample.git sample-original

# Create your own repositories and push
# Config repository
cd ~/thesis
cp -r config-original config
cd config
rm -rf .git
git init
git add .
git commit -m "Initial commit - thesis infrastructure"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/config.git
git push -u origin main

# Backend repository
cd ~/thesis
cp -r be-original be
cd be
rm -rf .git
git init
git add .
git commit -m "Initial commit - thesis backend"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/thesis-be.git
git push -u origin main

# Frontend repository
cd ~/thesis
cp -r fe-original fe
cd fe
rm -rf .git
git init
git add .
git commit -m "Initial commit - thesis frontend"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/thesis-fe.git
git push -u origin main

# LLM service repository
cd ~/thesis
cp -r llm-original thesis-llm
cd thesis-llm
rm -rf .git
git init
git add .
git commit -m "Initial commit - thesis LLM service"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/thesis-llm.git
git push -u origin main

# Tester repository
cd ~/thesis
cp -r tester-original thesis-tester
cd thesis-tester
rm -rf .git
git init
git add .
git commit -m "Initial commit - thesis tester"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/thesis-tester.git
git push -u origin main

# Sample repository
cd ~/thesis
cp -r sample-original thesis-sample
cd thesis-sample
rm -rf .git
git init
git add .
git commit -m "Initial commit - thesis sample"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/thesis-sample.git
git push -u origin main

# Clean up original clones
cd ~/thesis
rm -rf *-original

# Verify all repositories are ready
ls -la
```

### 2.3 Verify Repository Upload

Check that all repositories are successfully uploaded to your GitHub account:

```bash
# Visit your GitHub profile and verify these repositories exist:
echo "Check these URLs (replace YOUR_USERNAME):"
echo "https://github.com/YOUR_USERNAME/config"
echo "https://github.com/YOUR_USERNAME/thesis-be"
echo "https://github.com/YOUR_USERNAME/thesis-fe"
echo "https://github.com/YOUR_USERNAME/thesis-llm"
echo "https://github.com/YOUR_USERNAME/thesis-tester"
echo "https://github.com/YOUR_USERNAME/thesis-sample"

# Verify you can clone from your repositories
cd /tmp
git clone https://github.com/YOUR_USERNAME/config.git test-config
ls test-config/
rm -rf test-config

echo "✅ If you can see the files, your repositories are successfully uploaded!"
```

### 2.4 Update Repository References

You'll need to update configuration files to point to your repositories:

```bash
cd ~/thesis/config

# Update ArgoCD application files to use your repositories
sed -i 's/ORIGINAL_OWNER/YOUR_USERNAME/g' be/backend-application.yaml
sed -i 's/ORIGINAL_OWNER/YOUR_USERNAME/g' fe/frontend-application.yaml
sed -i 's/ORIGINAL_OWNER/YOUR_USERNAME/g' llm/llm-application.yaml

# Update terraform.tfvars to use your GitHub username
sed -i 's/ghcr_username = ".*"/ghcr_username = "YOUR_USERNAME"/g' terraform.tfvars
```

### 2.5 Setup GitHub Actions Secrets

**🔑 For EACH repository** (be, fe, thesis-llm, thesis-tester), add these secrets:

Go to: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

**Required secrets for all repositories:**

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GH_TOKEN` | Your GitHub Personal Access Token | For GHCR push access |
| `GITHUB_TOKEN` | (Auto-provided by GitHub) | Default GitHub Actions token |

**Additional secrets for thesis-llm:**

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GEMINI_API_KEY` | Your Gemini API key | Get from [Google AI Studio](https://aistudio.google.com/app/apikey) |

### 2.6 Test GitHub Actions Workflows

**Test each repository's CI/CD pipeline:**

#### Test Backend (thesis-be)

```bash
cd ~/thesis/be

# Make a small change to trigger CI/CD
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main

# Check GitHub Actions
echo "Visit: https://github.com/YOUR_USERNAME/thesis-be/actions"
```

#### Test Frontend (thesis-fe)

```bash
cd ~/thesis/fe

# Make a small change to trigger CI/CD
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main

# Check GitHub Actions
echo "Visit: https://github.com/YOUR_USERNAME/thesis-fe/actions"
```

#### Test LLM Service (thesis-llm)

```bash
cd ~/thesis/thesis-llm

# Make a small change to trigger CI/CD
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main

# Check GitHub Actions
echo "Visit: https://github.com/YOUR_USERNAME/thesis-llm/actions"
```

#### Test Tester (thesis-tester)

```bash
cd ~/thesis/thesis-tester

# Make a small change to trigger CI/CD
echo "# Test deployment" >> README.md
git add README.md
git commit -m "test: trigger CI/CD pipeline"
git push origin main

# Check GitHub Actions
echo "Visit: https://github.com/YOUR_USERNAME/thesis-tester/actions"
```

### 2.7 Verify Docker Images

After GitHub Actions complete successfully, verify your images are pushed:

```bash
# Check your GitHub Container Registry
# Visit: https://github.com/YOUR_USERNAME?tab=packages

# Or use Docker CLI
docker pull ghcr.io/YOUR_USERNAME/thesis-be:latest
docker pull ghcr.io/YOUR_USERNAME/thesis-fe:latest
docker pull ghcr.io/YOUR_USERNAME/thesis-grading:latest
docker pull ghcr.io/YOUR_USERNAME/thesis-tester:latest
```

### 2.8 Troubleshoot GitHub Actions Issues

**Common GitHub Actions problems:**

#### Permission Issues

```bash
# If you get permission errors, check:
# 1. GitHub token has correct scopes (repo, write:packages)
# 2. Repository secrets are correctly named
# 3. GITHUB_TOKEN is available (it's auto-provided)
```

#### Image Push Failures

```bash
# If image push fails:
# 1. Verify GHCR login works locally
echo $YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# 2. Check package permissions in GitHub
# Go to: Settings → Actions → General → Workflow permissions
# Ensure "Read and write permissions" is selected
```

#### Workflow Not Triggering

```bash
# If workflows don't trigger:
# 1. Check .github/workflows/ directory exists
# 2. Verify YAML syntax is correct
# 3. Ensure you're pushing to the correct branch (usually 'main')
```

**✅ Checkpoint**: Before proceeding to Step 3, ensure:

- ✅ All repositories are uploaded to your GitHub account
- ✅ GitHub Actions workflows run successfully  
- ✅ Docker images are pushed to your GHCR
- ✅ No workflow failures in any repository

---

## ☁️ Step 3: Google Cloud Platform Setup

### 3.1 Create GCP Project

```bash
# Login to GCP
gcloud auth login

# Create a new project (replace with your preferred project ID)
export PROJECT_ID="your-thesis-project-$(date +%s)"
gcloud projects create $PROJECT_ID

# Set the project as default
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iam.googleapis.com
```

### 3.2 Create Service Account

```bash
# Create service account
gcloud iam service-accounts create terraform-sa \
    --description="Terraform service account for thesis project" \
    --display-name="Terraform SA"

# Grant necessary permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/container.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/resourcemanager.projectIamAdmin"
```

### 3.3 Download Service Account Key

```bash
# Download credentials
cd ~/thesis/config
gcloud iam service-accounts keys create credentials.json \
    --iam-account=terraform-sa@$PROJECT_ID.iam.gserviceaccount.com

# Verify the file was created
ls -la credentials.json
```

### 3.4 Reserve Static IP

```bash
# Reserve a static IP for your ingress
gcloud compute addresses create thesis-ingress-ip --global

# Get the IP address (save this for later)
export INGRESS_IP=$(gcloud compute addresses describe thesis-ingress-ip --global --format="value(address)")
echo "Your static IP: $INGRESS_IP"
```

---

## 📦 Step 4: GitHub Container Registry Setup

### 4.1 Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Select these scopes:
   - `repo` (Full control of private repositories)
   - `write:packages` (Upload packages to GitHub Package Registry)
   - `read:packages` (Download packages from GitHub Package Registry)
   - `delete:packages` (Delete packages from GitHub Package Registry)
4. Generate token and **save it securely**

### 4.2 Test GHCR Login

```bash
# Test login to GitHub Container Registry
echo $YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

---

## 🔐 Step 5: GitHub Secrets Configuration

For each repository (be, fe, thesis-llm, thesis-tester), add these GitHub repository secrets:

### 5.1 Required Secrets for All Repositories

Go to each repository: Settings → Secrets and variables → Actions → New repository secret

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GH_TOKEN` | Your GitHub Personal Access Token | For GHCR access and ArgoCD |
| `GITHUB_TOKEN` | (Usually auto-provided) | GitHub Actions default token |

### 5.2 Additional Secrets for LLM Service

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `GEMINI_API_KEY` | Your Gemini API key | Get from Google AI Studio |

---

## 🏗️ Step 6: Infrastructure Deployment

### 6.1 Update Configuration Files BEFORE Deployment

**⚠️ CRITICAL**: You MUST update these configuration files with your own values before deploying any infrastructure. Using the default values will cause deployment failures.

#### 📝 Files That MUST BE UPDATED

##### 1. `config/terraform.tfvars` - Infrastructure Configuration

```bash
cd ~/thesis/config
nano terraform.tfvars

# UPDATE THESE VALUES:
project_id   = "YOUR_GCP_PROJECT_ID"        # ⚠️ CHANGE THIS
region       = "asia-east2-a"               # ✅ OK to keep
cluster_name = "thesis-cluster"             # ✅ OK to keep or change

node_count    = 2                           # ✅ OK to keep
ghcr_username = "YOUR_GITHUB_USERNAME"      # ⚠️ CHANGE THIS
ghcr_token    = "YOUR_GITHUB_TOKEN"         # ⚠️ CHANGE THIS

db_name     = "thesisdb"                    # ✅ OK to keep
db_username = "postgres"                    # ✅ OK to keep  
db_password = "YOUR_SECURE_DB_PASSWORD"     # ⚠️ CHANGE THIS

grafana_admin_password = "YOUR_GRAFANA_PASSWORD"  # ⚠️ CHANGE THIS
argocd_admin_password  = "YOUR_ARGOCD_PASSWORD"   # ⚠️ CHANGE THIS

ingress_ip = "YOUR_STATIC_IP"               # ⚠️ CHANGE THIS (from Step 3.4)
```

##### 2. `config/secret.yaml` - Database Secrets

```bash
nano secret.yaml

# UPDATE THESE VALUES:
stringData:
  db_name: thesisdb                         # ✅ OK to keep
  db_username: postgres                     # ✅ OK to keep
  db_password: YOUR_SECURE_DB_PASSWORD      # ⚠️ CHANGE THIS (same as terraform.tfvars)
  DATASOURCE_URL: "postgresql://postgres:YOUR_SECURE_DB_PASSWORD@postgres-headless.my-thesis.svc.cluster.local:5432/thesisdb?sslmode=disable"  # ⚠️ UPDATE PASSWORD
  GHCT_TOKEN: ${github_token}               # ✅ OK to keep (terraform will replace)
```

##### 3. `config/configmap.yaml` - Application Configuration

```bash
nano configmap.yaml

# UPDATE THESE VALUES:
  CLIENT_ORIGIN: "http://YOUR_STATIC_IP/app"                    # ⚠️ CHANGE IP
  NEXT_PUBLIC_GRAPHQL_URI: "http://YOUR_STATIC_IP/api/graphql"  # ⚠️ CHANGE IP
  BACKEND_URL: "http://YOUR_STATIC_IP/api/graphql"              # ⚠️ CHANGE IP
  COOKIE_DOMAIN: "YOUR_STATIC_IP"                               # ⚠️ CHANGE IP
  
  # RabbitMQ - OK to keep these or change for security:
  RABBITMQ_PASSWORD: "S3cur3P@ssw0rd123!"                      # ✅ OK or change
  
  # LLM Database - OK to keep these or change for security:
  DB_PASSWORD: "grading_password"                               # ✅ OK or change
```

##### 4. Backend Repository Configuration

```bash
cd ~/thesis/be

# Check for any hardcoded values in these files:
grep -r "34.92.62.138" . || echo "No hardcoded IPs found"
grep -r "reference-fact" . || echo "No project IDs found"
grep -r "tpSpace" . || echo "No hardcoded usernames found"

# If found, update them manually:
# nano src/index.js
# nano k8s/*.yaml
```

##### 5. Frontend Repository Configuration

```bash
cd ~/thesis/fe

# Check for any hardcoded values:
grep -r "34.92.62.138" . || echo "No hardcoded IPs found"
grep -r "reference-fact" . || echo "No project IDs found"

# If found, update them manually:
# nano k8s/*.yaml
# nano src/utils/apollo-client.js (if exists)
```

##### 6. LLM Service Repository Configuration

```bash
cd ~/thesis/thesis-llm

# Check for any hardcoded values:
grep -r "34.92.62.138" . || echo "No hardcoded IPs found"
grep -r "reference-fact" . || echo "No project IDs found"

# Update environment example file:
nano env.hybrid-local.example

# UPDATE YOUR GEMINI API KEY:
GEMINI_API_KEY=your_actual_gemini_api_key_here
```

#### 🔍 Verification Checklist

**Before proceeding, verify you've updated:**

```bash
cd ~/thesis/config

echo "=== VERIFICATION CHECKLIST ==="
echo "1. terraform.tfvars - Project ID: $(grep 'project_id' terraform.tfvars)"
echo "2. terraform.tfvars - GitHub username: $(grep 'ghcr_username' terraform.tfvars)"  
echo "3. terraform.tfvars - Static IP: $(grep 'ingress_ip' terraform.tfvars)"
echo "4. secret.yaml - DB password changed: $(grep 'db_password:' secret.yaml | grep -v 'conghoaxa' && echo 'YES' || echo 'NO - CHANGE IT!')"
echo "5. configmap.yaml - IP updated: $(grep 'CLIENT_ORIGIN:' configmap.yaml | grep -v '34.92.62.138' && echo 'YES' || echo 'NO - CHANGE IT!')"

echo ""
echo "🔐 SECURITY REMINDER:"
echo "- All passwords should be changed from defaults"
echo "- GitHub tokens should be valid and have correct permissions"
echo "- Static IP should match your reserved GCP IP"
echo "- Project ID should match your actual GCP project"
```

**✅ Only proceed when ALL values are updated!**

#### 📤 Commit Configuration Changes

```bash
cd ~/thesis/config

# Commit all configuration changes to git
git add terraform.tfvars secret.yaml configmap.yaml
git commit -m "feat: update configuration with personal values

- Update terraform.tfvars with project details
- Update secret.yaml with secure passwords  
- Update configmap.yaml with static IP
- Remove all hardcoded default values"

git push origin main

echo "✅ Configuration changes committed and pushed"
```

### 6.2 Deploy Infrastructure

```bash
cd ~/thesis/config

# Verify terraform.tfvars is properly configured (should be done in Step 6.1)
cat terraform.tfvars

# Verify all values are YOUR values, not the defaults
echo "⚠️ If you see 'reference-fact-465909-i2', 'tpSpace', or '34.92.62.138' - GO BACK TO STEP 6.1!"
```

### 6.3 Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan deployment (review changes)
terraform plan

# Deploy infrastructure (this takes 10-15 minutes)
terraform apply
```

**⚠️ Important**: If you get errors about Kubernetes provider, run in two phases:

```bash
# Phase 1: Create GKE cluster only
terraform apply -target=google_container_cluster.gke -target=google_container_node_pool.node_pool

# Phase 2: Deploy everything else
terraform apply
```

### 6.4 Configure kubectl

```bash
# Get GKE credentials
gcloud container clusters get-credentials thesis-cluster --region=asia-east2-a --project=$PROJECT_ID

# Verify connection
kubectl get nodes
kubectl get namespaces
```

### 6.5 Update IP Configuration

**🔧 CRITICAL**: Update all configuration files to use your actual static IP address:

```bash
cd ~/thesis/config

# Update main configmap with your static IP
sed -i "s/34\.92\.62\.138/$INGRESS_IP/g" configmap.yaml

# Update frontend configmap  
cd ~/thesis/fe
find . -name "*.yaml" -o -name "*.json" -o -name "*.js" | xargs sed -i "s/34\.92\.62\.138/$INGRESS_IP/g"

# Update backend configuration
cd ~/thesis/be  
find . -name "*.js" -o -name "*.yaml" -o -name "*.json" | xargs sed -i "s/34\.92\.62\.138/$INGRESS_IP/g"

# Update LLM service configuration
cd ~/thesis/thesis-llm
find . -name "*.js" -o -name "*.ts" -o -name "*.yaml" -o -name "*.json" | xargs sed -i "s/34\.92\.62\.138/$INGRESS_IP/g"

# Commit changes to all repositories
cd ~/thesis/config
git add . && git commit -m "Update IP configuration to $INGRESS_IP" && git push

cd ~/thesis/be
git add . && git commit -m "Update IP configuration to $INGRESS_IP" && git push

cd ~/thesis/fe  
git add . && git commit -m "Update IP configuration to $INGRESS_IP" && git push

cd ~/thesis/thesis-llm
git add . && git commit -m "Update IP configuration to $INGRESS_IP" && git push

echo "✅ IP configuration updated to: $INGRESS_IP"
```

---

## 🗃️ Step 7: Database Initialization & Schema Setup

**⚠️ CRITICAL**: After infrastructure deployment, you must initialize the databases and run schema migrations before deploying services.

### 7.1 Wait for Database Services

```bash
# Wait for PostgreSQL services to be ready
kubectl wait --for=condition=ready pod -l app=postgres -n my-thesis --timeout=300s
kubectl wait --for=condition=ready pod -l app=postgres-llm -n my-thesis --timeout=300s

# Verify database services are running
kubectl get pods -n my-thesis | grep postgres
```

### 7.2 Initialize Main Database Schema (Prisma)

```bash
# Port forward to main PostgreSQL database
kubectl port-forward svc/postgres 5432:5432 -n my-thesis &

# Wait a moment for port forward to establish
sleep 5

# Navigate to backend directory
cd ~/thesis/be

# Install dependencies if not already done
npm install
# or if using bun
bun install

# Run Prisma migrations to create database schema
bunx prisma migrate deploy

# Or if using npm
npx prisma migrate deploy

# Generate Prisma client
bunx prisma generate

# Or if using npm  
npx prisma generate

echo "✅ Main database schema initialized"
```

### 7.3 Seed Database with Initial Roles and Users

```bash
# Still in ~/thesis/be directory
# Run the seed script to create initial roles and users
bunx prisma db seed

# Or if using npm
npx prisma db seed

# Or run seed script directly
node prisma/seed.js

echo "✅ Database seeded with initial data"
```

### 7.4 Initialize LLM Database

```bash
# The LLM database should be automatically initialized by the database-init-job
# Check if the initialization job completed
kubectl get jobs -n my-thesis | grep grading-service-db-init

# If the job doesn't exist, apply it manually
cd ~/thesis/thesis-llm
kubectl apply -f k8s/database-init-job.yaml

# Wait for the job to complete
kubectl wait --for=condition=complete job/grading-service-db-init -n my-thesis --timeout=300s

# Check job logs
kubectl logs -l job-name=grading-service-db-init -n my-thesis

echo "✅ LLM database initialized"
```

### 7.5 Verify Database Setup

```bash
# Test main database connection and verify schema
cd ~/thesis/be

# Run health check
node prisma/health.js

# Connect to main database to verify tables
kubectl port-forward svc/postgres 5432:5432 -n my-thesis &
sleep 2

# Check if tables exist (optional - requires psql client)
PGPASSWORD="YOUR_DB_PASSWORD" psql -h localhost -U postgres -d thesisdb -c "\dt"

# Test main database connection
PGPASSWORD="YOUR_DB_PASSWORD" psql -h localhost -U postgres -d thesisdb -c "SELECT * FROM role;"

# Test LLM database connection  
kubectl port-forward svc/postgres-llm 5433:5432 -n my-thesis &
sleep 2

PGPASSWORD="grading_password" psql -h localhost -p 5433 -U grading_user -d grading_service -c "\dt"

# Kill port forwards
pkill -f "kubectl port-forward"

echo "✅ Database verification completed"
```

### 7.6 Created Database Accounts

**📋 Default accounts created by seed script:**

| Role | Username | Password | Email |
|------|----------|----------|-------|
| Admin | `admin_user` | `admin123` | `admin@lcasystem.com` |
| Teacher | `teacher_john` | `teacher123` | `john.teacher@lcasystem.com` |
| Student | `student_jane` | `student123` | `jane.student@lcasystem.com` |

**🔐 Database Users:**

| Database | Username | Password | Database Name |
|----------|----------|----------|---------------|
| Main | `postgres` | `YOUR_DB_PASSWORD` | `thesisdb` |
| LLM | `grading_user` | `grading_password` | `grading_service` |

**✅ Checkpoint**: Before proceeding to Step 8, ensure:

- ✅ Main database schema is migrated (Prisma)
- ✅ Database is seeded with roles and users
- ✅ LLM database is initialized with schema
- ✅ Database connections are working
- ✅ No database connection errors

---

## 🚀 Step 8: Service Deployment

### 8.1 Verify Infrastructure Services

```bash
# Check all pods in my-thesis namespace
kubectl get pods -n my-thesis

# Check ArgoCD pods
kubectl get pods -n argocd

# Should see: postgres, rabbitmq, argocd-server, etc.
```

### 7.2 Setup ArgoCD Access

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # Print newline

# Port forward to access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access ArgoCD at: https://localhost:8080
# Username: admin
# Password: (from command above)
```

### 7.3 Configure GitHub Repository Access in ArgoCD

1. Login to ArgoCD UI
2. Go to Settings → Repositories
3. Add your repositories:
   - Repository URL: `https://github.com/YOUR_USERNAME/thesis-be.git`
   - Username: Your GitHub username
   - Password: Your GitHub token
   - Repeat for `thesis-fe` and `thesis-llm`

### 7.4 Deploy Applications via ArgoCD

```bash
# Apply ArgoCD applications
kubectl apply -f be/backend-application.yaml
kubectl apply -f fe/frontend-application.yaml
kubectl apply -f llm/llm-application.yaml

# Check application status
kubectl get applications -n argocd
```

### 7.5 Build and Push Docker Images

#### For Backend

```bash
cd ~/thesis/be
# Make sure you have a Dockerfile and .github/workflows/ci-cd-pipeline.yml
# Push to main branch to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

#### For Frontend

```bash
cd ~/thesis/fe
# Make sure you have a Dockerfile and .github/workflows/ci-cd-pipeline.yml
# Push to main branch to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

#### For LLM Service

```bash
cd ~/thesis/thesis-llm
# Make sure you have Gemini API key configured
# Push to main branch to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

#### For Tester

```bash
cd ~/thesis/thesis-tester
# Push to main branch to trigger CI/CD
git add .
git commit -m "Initial deployment"
git push origin main
```

---

## ✅ Step 9: Verification & Testing

### 9.1 Check All Services

```bash
# Check pods in my-thesis namespace
kubectl get pods -n my-thesis

# Check services
kubectl get svc -n my-thesis

# Check ingress
kubectl get ingress -n my-thesis
```

### 9.2 Access Applications

```bash
# Get the external IP
echo "Your application will be available at: http://$INGRESS_IP"

# Frontend: http://YOUR_IP/app
# Backend API: http://YOUR_IP/api
# ArgoCD: http://YOUR_IP/argocd (or port-forward as shown above)
```

### 9.3 Test RabbitMQ (for LLM service)

```bash
# Port forward RabbitMQ management
kubectl port-forward svc/rabbitmq 15672:15672 -n my-thesis &

# Access RabbitMQ management at: http://localhost:15672
# Username: rabbit-user
# Password: S3cur3P@ssw0rd123!
```

### 9.4 Test Database Connection

```bash
# Port forward PostgreSQL
kubectl port-forward svc/postgres 5432:5432 -n my-thesis &

# Connect to main database
psql -h localhost -U postgres -d thesisdb

# Port forward LLM PostgreSQL
kubectl port-forward svc/postgres-llm 5433:5432 -n my-thesis &

# Connect to LLM database
psql -h localhost -p 5433 -U grading_user -d grading_service
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Terraform Apply Fails

```bash
# Clean up and retry
terraform destroy
rm -rf .terraform/
terraform init
terraform apply
```

#### 2. kubectl Cannot Connect to Cluster

```bash
# Re-authenticate
gcloud auth login
gcloud container clusters get-credentials thesis-cluster --region=asia-east2-a --project=$PROJECT_ID
```

#### 3. ArgoCD Applications Not Syncing

```bash
# Check repository access
kubectl get secrets -n argocd | grep repo
kubectl describe secret argocd-repo-server-tls -n argocd

# Restart ArgoCD
kubectl rollout restart deployment argocd-server -n argocd
```

#### 4. Pods in CrashLoopBackOff

```bash
# Check pod logs
kubectl logs <pod-name> -n my-thesis

# Check events
kubectl describe pod <pod-name> -n my-thesis

# Check if secrets/configmaps exist
kubectl get secrets -n my-thesis
kubectl get configmaps -n my-thesis
```

#### 5. Cannot Pull Docker Images

```bash
# Check if GHCR secret exists
kubectl get secrets -n my-thesis | grep ghcr

# Recreate GHCR secret if needed
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=YOUR_GITHUB_USERNAME \
  --docker-password=YOUR_GITHUB_TOKEN \
  --namespace=my-thesis
```

---

## 📚 Useful Commands

### Monitoring

```bash
# Watch all pods
kubectl get pods -n my-thesis -w

# Check resource usage
kubectl top nodes
kubectl top pods -n my-thesis

# View logs
kubectl logs -f deployment/backend -n my-thesis
kubectl logs -f deployment/frontend -n my-thesis
kubectl logs -f deployment/llm-grading-service -n my-thesis
```

### Debugging

```bash
# Execute into a pod
kubectl exec -it <pod-name> -n my-thesis -- /bin/bash

# Port forward services for testing
kubectl port-forward svc/backend 4000:4000 -n my-thesis &
kubectl port-forward svc/frontend 3000:3000 -n my-thesis &
```

### Cleanup

```bash
# Delete applications
kubectl delete applications --all -n argocd

# Destroy infrastructure
terraform destroy

# Delete GCP project (complete cleanup)
gcloud projects delete $PROJECT_ID
```

### ArgoCD Management

```bash
# Sync applications manually
kubectl patch application backend -n argocd -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"hook":{}}}}}' --type merge

# Check application health
kubectl get applications -n argocd -o wide
```

---

## 🎯 Next Steps

After successful deployment:

1. **Configure DNS** (optional): Point your domain to the static IP
2. **Setup SSL/TLS** (optional): Add Let's Encrypt certificates
3. **Configure monitoring**: Access Grafana dashboards
4. **Test the grading workflow**: Submit sample assignments
5. **Scale services**: Adjust replicas based on usage

---

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs: `kubectl logs <pod-name> -n my-thesis`
3. Verify configuration: `kubectl describe <resource> -n my-thesis`
4. Check GitHub Actions workflows for CI/CD issues
5. Ensure all secrets and credentials are correctly configured

---

## 📝 Security Notes

- **Never commit sensitive data** (credentials, tokens) to Git
- **Use strong passwords** for all services
- **Regularly rotate** GitHub tokens and API keys
- **Enable 2FA** on all accounts (GitHub, GCP, etc.)
- **Review IAM permissions** regularly
- **Monitor resource usage** to avoid unexpected costs

---

**Congratulations!** 🎉 You now have a fully functional microservices-based automated grading system running on GKE with GitOps deployment via ArgoCD.
