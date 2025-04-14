provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0.0"
    }
  }
}

# # Networking
# resource "google_compute_network" "vpc" {
#   name                    = "gke-vpc"
#   auto_create_subnetworks = true

#   lifecycle {
#     prevent_destroy = true
#   }
# }

# GKE Cluster
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  # network    = google_compute_network.vpc.name

}

# Node Pool
resource "google_container_node_pool" "node_pool" {
  name       = "app-node-pool"
  cluster    = google_container_cluster.gke.id
  node_count = var.node_count

  node_config {
    machine_type = "e2-small"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }
}

# Kubernetes Providers
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

provider "kubectl" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}

# Namespace
resource "kubernetes_namespace" "my_thesis" {
  metadata {
    name = "my-thesis"
  }
}

# GHCR Secret
resource "kubernetes_secret" "ghcr_secret" {
  metadata {
    name      = "ghcr-secret"
    namespace = "my-thesis"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ghcr.io" = {
          auth = base64encode("${var.ghcr_username}:${var.ghcr_token}")
        }
      }
    })
  }
}

# Database Secret
resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = "my-thesis"
  }

  data = {
    db_name     = base64encode(var.db_name)
    db_username = base64encode(var.db_username)
    db_password = base64encode(var.db_password)
  }

  type = "Opaque"
}

# Apply Kustomize
resource "kubectl_manifest" "kustomize" {
  depends_on = [
    kubernetes_namespace.my_thesis,
    kubernetes_secret.ghcr_secret,
    kubernetes_secret.db_credentials
  ]
  yaml_body = file("./kustomization.yaml")
}