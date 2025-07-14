# Thesis Infrastructure Repository

## 📚 Complete Documentation

**👉 For comprehensive setup and usage instructions, see: [COMPLETE-THESIS-INFRASTRUCTURE-GUIDE.md](./COMPLETE-THESIS-INFRASTRUCTURE-GUIDE.md)**

## Quick Overview

This repository contains the infrastructure configuration for the thesis project, implementing GitOps principles with ArgoCD for automated deployment of frontend and backend services.

## Services

- **Backend Service**: Exposes the backend application on port 4000.
- **Frontend Service**: Exposes the frontend application on port 80.

## Deployment

The deployment files define the specifications for the backend and frontend applications, including environment variables and resource limits.

## Directory Structure

```plaintext
.
├── main.tf
├── variables.tf
├── terraform.tfvars
├── configmap.yaml
├── service-db.yaml
├── statefulset-db.yaml
├── service-backend.yaml
├── deployment-backend.yaml
├── service-frontend.yaml
├── deployment-frontend.yaml
└── README.md
```

## Usage

```bash
# Stage 1: Create only the GKE infrastructure
terraform apply -target=google_container_cluster.gke -target=google_container_node_pool.node_pool

# Get credentials after cluster is created
gcloud container clusters get-credentials ${var.cluster_name} --region=${var.region}

# Stage 2: Apply the Kubernetes resources
terraform apply
```

## kubectl

Show all pods in the `my-thesis` namespace:

```bash
 kubectl get pods -n my-thesis
```

Show all pods in the `my-thesis` namespace with additional information:

```bash
 kubectl get pods -n my-thesis -o wide
```

Argocd
Access the ArgoCD UI

```bash
kubectl get svc argocd-server -n argocd
```

Get the ArgoCD password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

```bash
NNNISSqQcReG9vKc
```

## Restart ArgoCD Deployments

```bash
kubectl rollout restart deployment -l app.kubernetes.io/part-of=argocd -n argocd
```

## Installation on GCP

1. Create Project then create service account
2. Donwload Service Account credentials.json
3. Delete unecessasry files such as terrform.tfstate, .terraform.tfstate.lock.info, etc any files related temp files.
4. Also login to gcloud.

```bash
terraform init
terraform plan
terraform apply
```

## Get all services & ip type

```bash
 kubectl get svc --all-namespaces -o wide
```

## How to reroll a pod

```bash
   kubectl get pods -n my-thesis -l app=postgres
```

```bash
   kubectl exec -it <pod-name> -n my-thesis -- bash
   kubectl exec -it frontend-748bd554d8-28t8s -n my-thesis -- sh
```

```bash
   kubectl exec -it <pod-name> -n my-thesis -- sh
```

```bash
   psql -U postgres
```

```bash
   kubectl rollout restart deployment frontend -n my-thesis
```

## Forward-port for rabbitmq

```bash
   kubectl port-forward svc/rabbitmq 15672:15672 -n my-thesis
```

# Run all port forwards in background

```bash
kubectl port-forward -n my-thesis service/rabbitmq 5672:5672 &
kubectl port-forward -n my-thesis service/rabbitmq 15672:15672 &
kubectl port-forward -n my-thesis service/postgres-llm 5433:5432 &
```

# To see background jobs

```bash
jobs
```

# To kill all background jobs when done

```bash
kill %1 %2 %3 %4
```

<!-- Unable to load data: error getting cached app managed resources: InvalidSpecError: application repo git@github.com:tpSpace/infra.git is not permitted in project 'thesis' -->

## IMPORTANT: Due to Kubernetes provider dependencies, you may need to run terraform apply in two phases

## 1. First apply only the GKE cluster and node pool

```bash
   terraform apply -target=google_container_cluster.gke -target=google_container_node_pool.node_pool
```

## 2. Then apply the rest of the infrastructure:

```bash
    terraform apply
```

## Alternatively, ensure you have authenticated with gcloud and have the cluster credentials:

```bash
 gcloud auth application-default login
```

```bash
 gcloud container clusters get-credentials thesis-cluster --region=asia-east2-a --project=your-project-id
```

## record time

### Create GKE infra

- 18h25 -> 18h35 10m to create GKE
- 18h45 -> 18h48 3m to setup all services
