#!/bin/bash

echo "� ArgoCD SSH Configuration Setup"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Step 1: Verify SSH key files exist
echo
echo "📋 Step 1: Verifying SSH configuration files..."

if [ ! -f "argocd-github-infra" ]; then
    print_error "SSH private key 'argocd-github-infra' not found!"
    exit 1
fi
print_status "SSH private key found"

if [ ! -f "argocd-github-infra.pub" ]; then
    print_error "SSH public key 'argocd-github-infra.pub' not found!"
    exit 1
fi
print_status "SSH public key found"

# Step 2: Verify secret YAML files exist
if [ ! -f "ssh-known-hosts-secret.yaml" ]; then
    print_error "SSH known hosts secret file not found!"
    exit 1
fi
print_status "SSH known hosts secret file found"

if [ ! -f "github-ssh-repo-secret.yaml" ]; then
    print_error "GitHub SSH repo secret file not found!"
    exit 1
fi
print_status "GitHub SSH repo secret file found"

# Step 3: Display public key for GitHub setup verification
echo
echo "📋 Step 2: SSH Public Key Information"
echo "======================================"
print_info "Please ensure this public key is added to your GitHub repository:"
echo
cat argocd-github-infra.pub
echo
print_warning "The key should be added as a Deploy Key in your GitHub repository settings"
print_warning "Repository: https://github.com/tpSpace/infra"
print_warning "Settings > Deploy keys > Add deploy key"

# Step 4: Test SSH key format
echo
echo "� Step 3: SSH Key Validation"
echo "============================="
print_info "Testing SSH key format..."
ssh-keygen -lf argocd-github-infra.pub

# Step 5: Verify Terraform is initialized
echo
echo "📋 Step 4: Terraform Verification"
echo "================================="

if [ ! -d ".terraform" ]; then
    print_warning "Terraform not initialized. Running terraform init..."
    terraform init
    if [ $? -eq 0 ]; then
        print_status "Terraform initialized successfully"
    else
        print_error "Failed to initialize Terraform"
        exit 1
    fi
else
    print_status "Terraform already initialized"
fi

# Step 6: Plan the changes
echo
echo "📋 Step 5: Planning Terraform Changes"
echo "====================================="
print_info "Planning SSH secrets deployment..."

terraform plan -target=kubectl_manifest.argocd_ssh_known_hosts -target=kubectl_manifest.github_repo_creds

if [ $? -ne 0 ]; then
    print_error "Terraform plan failed!"
    exit 1
fi

# Step 7: Ask for confirmation
echo
echo "📋 Step 6: Deployment Confirmation"
echo "=================================="
read -p "Do you want to apply the SSH configuration? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo
    print_info "🚀 Applying SSH configuration..."
    
    # Apply SSH secrets first
    print_info "Deploying SSH secrets..."
    terraform apply -target=kubectl_manifest.argocd_ssh_known_hosts -target=kubectl_manifest.github_repo_creds -auto-approve
    
    if [ $? -eq 0 ]; then
        print_status "SSH secrets deployed successfully"
    else
        print_error "Failed to deploy SSH secrets"
        exit 1
    fi
    
    # Then apply ArgoCD changes
    print_info "Updating ArgoCD configuration..."
    terraform apply -target=helm_release.argocd -auto-approve
    
    if [ $? -eq 0 ]; then
        print_status "ArgoCD updated successfully"
    else
        print_error "Failed to update ArgoCD"
        exit 1
    fi
    
    # Finally apply applications
    print_info "Deploying ArgoCD applications..."
    terraform apply -target=kubectl_manifest.argocd_apps -auto-approve
    
    if [ $? -eq 0 ]; then
        print_status "ArgoCD applications deployed successfully"
    else
        print_error "Failed to deploy ArgoCD applications"
        exit 1
    fi
    
    echo
    print_status "🎉 ArgoCD SSH configuration completed successfully!"
    echo
    echo "📋 What was deployed:"
    echo "===================="
    echo "✅ SSH Known Hosts Secret (argocd-ssh-known-hosts-cm)"
    echo "✅ GitHub Repository Credentials (github-ssh-repo-secret)"
    echo "✅ ArgoCD Helm Release (updated with SSH support)"
    echo "✅ ArgoCD Applications"
    echo
    echo "🔍 Next Steps:"
    echo "=============="
    echo "1. Access ArgoCD UI to verify repository connection"
    echo "2. Check that applications can sync from GitHub"
    echo "3. Monitor ArgoCD logs for any SSH-related issues"
    echo
    print_info "ArgoCD UI should be accessible via your configured ingress"
    echo
    echo "🔧 Troubleshooting commands:"
    echo "kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server"
    echo "kubectl get secrets -n argocd"
    
else
    print_warning "Deployment cancelled by user"
    echo
    echo "📋 To deploy later, run:"
    echo "./apply-ssh-config.sh"
fi
