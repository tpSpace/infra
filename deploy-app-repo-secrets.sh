#!/bin/bash

# Script to deploy ArgoCD repository configurations for application repos

echo "Deploying ArgoCD repository configurations for application repos..."

# Deploy FE repository configuration
echo "Deploying FE repository configuration..."
kubectl apply -f argocd-fe-repo-config.yaml
if [ $? -eq 0 ]; then
    echo "✅ FE repository configuration deployed successfully"
else
    echo "❌ Failed to deploy FE repository configuration"
    exit 1
fi

# Deploy BE repository configuration
echo "Deploying BE repository configuration..."
kubectl apply -f argocd-be-repo-config.yaml
if [ $? -eq 0 ]; then
    echo "✅ BE repository configuration deployed successfully"
else
    echo "❌ Failed to deploy BE repository configuration"
    exit 1
fi

echo ""
echo "🔄 Restarting ArgoCD components to pick up new repository configurations..."

# Restart ArgoCD components to pick up new repositories
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd

echo ""
echo "⏳ Waiting for ArgoCD components to be ready..."
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-application-controller -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s

echo ""
echo "✅ All ArgoCD repository configurations deployed successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Apply the updated ArgoCD applications:"
echo "   kubectl apply -f be/backend-application.yaml"
echo "   kubectl apply -f fe/frontend-application.yaml"
echo ""
echo "2. Commit and push the new K8s configs to your application repos:"
echo "   cd ../lcasystem-FE && git add k8s/ && git commit -m 'Add K8s manifests' && git push"
echo "   cd ../lcasystem-BE && git add k8s/ && git commit -m 'Add K8s manifests' && git push"
echo ""
echo "3. Verify the repositories are accessible in ArgoCD UI"
echo "4. Check that applications sync when changes are made to FE/BE repos" 