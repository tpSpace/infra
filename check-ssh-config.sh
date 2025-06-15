#!/bin/bash

echo "🔍 ArgoCD SSH Configuration Status Check"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header() {
    echo
    echo -e "${BLUE}📋 $1${NC}"
    echo "$(printf '=%.0s' {1..50})"
}

# Check SSH files
print_header "SSH Files Status"

if [ -f "argocd-github-infra" ]; then
    print_status "SSH private key exists"
else
    print_error "SSH private key missing"
fi

if [ -f "argocd-github-infra.pub" ]; then
    print_status "SSH public key exists"
    echo "Public key content:"
    cat argocd-github-infra.pub
else
    print_error "SSH public key missing"
fi

# Check secret files
print_header "Kubernetes Secret Files"

if [ -f "ssh-known-hosts-secret.yaml" ] && [ -s "ssh-known-hosts-secret.yaml" ]; then
    print_status "SSH known hosts secret file exists and is not empty"
else
    print_error "SSH known hosts secret file missing or empty"
fi

if [ -f "github-ssh-repo-secret.yaml" ] && [ -s "github-ssh-repo-secret.yaml" ]; then
    print_status "GitHub SSH repo secret file exists and is not empty"
else
    print_error "GitHub SSH repo secret file missing or empty"
fi

# Check Terraform status
print_header "Terraform Status"

if [ -d ".terraform" ]; then
    print_status "Terraform initialized"
else
    print_warning "Terraform not initialized - run 'terraform init'"
fi

if [ -f "terraform.tfstate" ]; then
    print_status "Terraform state file exists"
else
    print_warning "No Terraform state file found"
fi

# Check if kubectl is configured
print_header "Kubernetes Cluster Access"

if kubectl cluster-info >/dev/null 2>&1; then
    print_status "Kubernetes cluster accessible"
    
    # Check if ArgoCD namespace exists
    if kubectl get namespace argocd >/dev/null 2>&1; then
        print_status "ArgoCD namespace exists"
        
        # Check secrets
        if kubectl get secret argocd-ssh-known-hosts-cm -n argocd >/dev/null 2>&1; then
            print_status "SSH known hosts secret deployed"
        else
            print_warning "SSH known hosts secret not deployed"
        fi
        
        if kubectl get secret github-ssh-repo-secret -n argocd >/dev/null 2>&1; then
            print_status "GitHub repo secret deployed"
        else
            print_warning "GitHub repo secret not deployed"
        fi
        
        # Check ArgoCD pods
        ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
        if [ "$ARGOCD_PODS" -gt 0 ]; then
            print_status "ArgoCD pods running ($ARGOCD_PODS pods)"
            
            # Check pod status
            RUNNING_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running")
            if [ "$RUNNING_PODS" -eq "$ARGOCD_PODS" ]; then
                print_status "All ArgoCD pods are running"
            else
                print_warning "$RUNNING_PODS/$ARGOCD_PODS ArgoCD pods are running"
            fi
        else
            print_warning "No ArgoCD pods found"
        fi
        
    else
        print_warning "ArgoCD namespace not found"
    fi
    
else
    print_error "Cannot access Kubernetes cluster"
fi

# GitHub SSH connection test
print_header "GitHub SSH Access Test"

print_info "Testing SSH connection to GitHub..."
if ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
    print_status "SSH connection to GitHub successful"
else
    print_warning "SSH connection to GitHub failed (this might be expected if key not added)"
fi

# Summary and next steps
print_header "Summary & Next Steps"

echo
print_info "To complete the SSH configuration:"
echo
echo "1. 🔑 Add the SSH public key to GitHub:"
echo "   Repository: https://github.com/tpSpace/infra"
echo "   Settings > Deploy keys > Add deploy key"
echo
echo "2. 🚀 Deploy the configuration:"
echo "   ./apply-ssh-config.sh"
echo
echo "3. 🔍 Verify ArgoCD connection:"
echo "   Check ArgoCD UI for repository status"
echo
echo "📚 For detailed instructions, see: ARGOCD_SSH_SETUP_GUIDE.md"
