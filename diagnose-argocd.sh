#!/bin/bash

echo "🔍 ArgoCD SSH Troubleshooting Script"
echo "===================================="

# Check if ArgoCD is running
echo "1. Checking ArgoCD pods status..."
kubectl get pods -n argocd

echo ""
echo "2. Checking ArgoCD repository secret..."
kubectl get secret github-ssh-repo-secret -n argocd -o yaml

echo ""
echo "3. Checking SSH known hosts secret..."
kubectl get secret argocd-ssh-known-hosts-cm -n argocd -o yaml

echo ""
echo "4. Checking ArgoCD applications..."
kubectl get applications -n argocd

echo ""
echo "5. Checking repository connection in ArgoCD..."
echo "   (This will show repository connectivity status)"
kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.status.sync.status} - {.status.health.status}{"\n"}{end}'

echo ""
echo "6. Recent ArgoCD repo-server logs..."
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=20

echo ""
echo "7. Recent ArgoCD application-controller logs..."
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=20

echo ""
echo "🎯 If you see 'unable to resolve main to a commit SHA', try:"
echo "   1. Make sure the SSH key is added to GitHub with repo access"
echo "   2. Verify the repository uses 'master' branch (not 'main')"
echo "   3. Check if ArgoCD can actually connect via SSH"
