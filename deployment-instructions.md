# ArgoCD Deployment Instructions

This document provides step-by-step instructions for setting up ArgoCD and deploying your thesis frontend and backend applications using GitOps principles.

## Prerequisites

- Kubernetes cluster is up and running
- `kubectl` is installed and configured to access your cluster
- You have access to the GitHub repositories:
  - Frontend: <https://github.com/tpSpace/thesis-fe.git>
  - Backend: <https://github.com/tpSpace/thesis-be.git>

## 1. Install ArgoCD  

```bash
# Create namespace for ArgoCD
kubectl create namespace argocd

# Install ArgoCD components
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all ArgoCD components to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl wait --for=condition=available --timeout=300s deployment/argocd-application-controller -n argocd
```

## 2. Access ArgoCD UI

```bash
# Port forward the ArgoCD server to access the UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

You can now access the ArgoCD UI at <https://localhost:8080>

To get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## 3. Apply ArgoCD Configurations

Apply the configuration files in the correct order:

```bash
# Apply the configurations in order
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-thesis-project.yaml
kubectl apply -f 02-github-repo-secret.yaml
kubectl apply -f 03-frontend-application.yaml
kubectl apply -f 04-backend-application.yaml
```

## 4. Verify Deployment

1. Check that the applications are created in ArgoCD:

```bash
kubectl get applications -n argocd
```

1. Verify that the applications are syncing:

```bash
kubectl get applications thesis-frontend thesis-backend -n argocd -o jsonpath='{.items[*].status.sync.status}'
```

1. Check that the pods are running in the my-thesis namespace:

```bash
kubectl get pods -n my-thesis
```

## 5. Automatic Updates

With the current configuration, ArgoCD will automatically:

- Poll your GitHub repositories for changes
- Detect when new commits are pushed
- Apply the changes to your Kubernetes cluster
- Prune resources that are no longer defined in the repository
- Self-heal if manual changes are made to the resources

## Troubleshooting

If you encounter issues with repository access:

1. Verify the GitHub token is valid:

```bash
kubectl get secret github-repo-creds-pattern -n argocd -o jsonpath='{.data.password}' | base64 -d
```

1. Check ArgoCD logs for repository connection issues:

```bash
kubectl logs -n argocd deployment/argocd-repo-server
```

1. If needed, update the repository secret with a new token:

```bash
kubectl patch secret github-repo-creds-pattern -n argocd --type='json' -p='[{"op": "replace", "path": "/stringData/password", "value": "your-new-token"}]'
```

## Additional Configuration

To modify the sync behavior or other application settings, edit the respective application YAML files and reapply them:

```bash
kubectl apply -f 03-frontend-application.yaml
kubectl apply -f 04-backend-application.yaml
```
