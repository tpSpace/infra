#!/bin/bash

echo "🚀 Setting up ArgoCD Multi-Repository Configuration"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Step 1: Show SSH public keys that need to be added to GitHub
print_step "📋 SSH Public Keys to Add to GitHub Repositories"
echo ""
echo "=== Add this key to thesis-fe repository ==="
echo "Repository: https://github.com/tpSpace/thesis-fe/settings/keys"
echo "Title: argocd-fe-access"
echo "Key:"
cat argocd-fe.pub
echo ""
echo "=== Add this key to thesis-be repository ==="
echo "Repository: https://github.com/tpSpace/thesis-be/settings/keys"
echo "Title: argocd-be-access"
echo "Key:"
cat argocd-be.pub
echo ""
echo "⚠️  IMPORTANT: Make sure to add these keys to GitHub before proceeding!"
echo ""
read -p "Have you added the SSH keys to GitHub? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_warning "Please add the SSH keys to GitHub first, then run this script again."
    exit 1
fi

# Step 2: Apply ArgoCD project configuration
print_step "🔧 Updating ArgoCD project configuration"
kubectl apply -f thesis-project.yaml
if [ $? -eq 0 ]; then
    print_success "ArgoCD project configuration updated"
else
    print_error "Failed to update ArgoCD project configuration"
    exit 1
fi

# Step 3: Apply repository configurations
print_step "🔑 Deploying repository SSH configurations"

echo "Deploying FE repository configuration..."
kubectl apply -f argocd-fe-repo-config.yaml
if [ $? -eq 0 ]; then
    print_success "FE repository configuration deployed"
else
    print_error "Failed to deploy FE repository configuration"
    exit 1
fi

echo "Deploying BE repository configuration..."
kubectl apply -f argocd-be-repo-config.yaml
if [ $? -eq 0 ]; then
    print_success "BE repository configuration deployed"
else
    print_error "Failed to deploy BE repository configuration"
    exit 1
fi

# Step 4: Restart ArgoCD components
print_step "🔄 Restarting ArgoCD components"
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd

print_step "⏳ Waiting for ArgoCD components to be ready"
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-application-controller -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s

# Step 5: Apply ArgoCD applications
print_step "📱 Updating ArgoCD applications"

echo "Applying backend application..."
kubectl apply -f be/backend-application.yaml
if [ $? -eq 0 ]; then
    print_success "Backend application updated"
else
    print_error "Failed to update backend application"
    exit 1
fi

echo "Applying frontend application..."
kubectl apply -f fe/frontend-application.yaml
if [ $? -eq 0 ]; then
    print_success "Frontend application updated"
else
    print_error "Failed to update frontend application"
    exit 1
fi

# Step 6: Show next steps
echo ""
print_success "🎉 ArgoCD Multi-Repository Setup Complete!"
echo ""
echo "📝 Next Steps:"
echo "1. Commit and push K8s manifests to your application repositories:"
echo "   cd ../lcasystem-FE && git add k8s/ && git commit -m 'Add K8s manifests for GitOps' && git push"
echo "   cd ../lcasystem-BE && git add k8s/ && git commit -m 'Add K8s manifests for GitOps' && git push"
echo ""
echo "2. Check ArgoCD UI to verify repositories are accessible:"
echo "   - Go to Settings > Repositories"
echo "   - Verify thesis-fe and thesis-be repos show 'Successful'"
echo ""
echo "3. Check application sync status:"
echo "   - Go to Applications"
echo "   - Both thesis-frontend and thesis-backend should sync automatically"
echo ""
echo "4. Test the setup by making a change to your application code"
echo ""
print_success "Setup completed successfully! 🚀" 