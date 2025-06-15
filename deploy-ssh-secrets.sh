#!/bin/bash

echo "🔧 Converting ArgoCD to use SSH authentication with secret configs..."

# Step 1: Verify SSH key exists
if [ ! -f "argocd-github-infra" ]; then
    echo "❌ SSH private key 'argocd-github-infra' not found!"
    exit 1
fi

echo "✅ SSH private key found"

# Step 2: Verify secret files exist
if [ ! -f "ssh-known-hosts-secret.yaml" ]; then
    echo "❌ SSH known hosts secret file not found!"
    exit 1
fi

if [ ! -f "github-ssh-repo-secret.yaml" ]; then
    echo "❌ GitHub SSH repo secret file not found!"
    exit 1
fi

echo "✅ Secret configuration files found"

# Step 3: Plan the changes
echo "📋 Planning Terraform changes..."
terraform plan -target=kubectl_manifest.argocd_ssh_known_hosts -target=kubectl_manifest.github_repo_creds

# Step 4: Ask for confirmation
read -p "Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Applying SSH configuration..."
    
    # Apply SSH secrets first
    terraform apply -target=kubectl_manifest.argocd_ssh_known_hosts -target=kubectl_manifest.github_repo_creds -auto-approve
    
    # Then apply ArgoCD changes
    terraform apply -target=helm_release.argocd -auto-approve
    
    # Finally apply applications
    terraform apply -target=kubectl_manifest.argocd_apps -auto-approve
    
    echo "✅ ArgoCD SSH configuration completed!"
    echo "🔍 Check ArgoCD UI to verify repository connection works"
    echo ""
    echo "📋 Secrets created:"
    echo "  - argocd-ssh-known-hosts-cm (SSH known hosts)"
    echo "  - github-ssh-repo-secret (Repository credentials)"
else
    echo "❌ Operation cancelled"
fi
