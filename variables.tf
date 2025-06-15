variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-east2-a"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = "thesis-cluster"
}

variable "node_count" {
  description = "Number of nodes in the GKE node pool"
  type        = number
  default     = 1
}

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "thesisdb"
}

variable "ghcr_username" {
  description = "GitHub Container Registry username"
  type        = string
}

variable "ghcr_token" {
  description = "GitHub Container Registry token"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "argocd_hostname" {
  description = "The hostname for ArgoCD UI access"
  type        = string
  default     = "argocd.local"
}

variable "argocd_admin_password" {
  description = "Admin password for ArgoCD"
  type        = string
  sensitive   = true
  default     = "argocd123!"
}

variable "github_username" {
  description = "GitHub username"
  type        = string
  default     = "tpSpace"
}

variable "github_token" {
  description = "GitHub token for ArgoCD repository access"
  type        = string
  sensitive   = true
}