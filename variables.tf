variable "project_id" {
  description = "The project ID to deploy resources"
  type        = string
  default     = "trans-radius-456716-n5"
}

variable "region" {
  description = "The region to deploy resources"
  type        = string
  default     = "asia-southeast1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "gke-cluster"
}

variable "node_count" {
  description = "The number of nodes in the node pool"
  type        = number
  default     = 2
}

variable "ghcr_username" {
  description = "GitHub username for Container Registry authentication"
  type        = string
  sensitive   = true
}

variable "ghcr_token" {
  description = "GitHub personal access token for Container Registry authentication"
  type        = string
  sensitive   = true
}