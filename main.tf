provider "google" {
  project = var.project_id
  region  = var.region
}
terraform {
   required_version = ">= 0.13"
   
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"  # Use latest stable version if needed
    }
  }
}

# Create VPC network
resource "google_compute_network" "vpc" {
  name                    = "gke-vpc"
  auto_create_subnetworks = false
}

# Create subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "gke-subnet"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
}

# Create GKE cluster
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.region

  # Remove default node pool after cluster creation
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Create custom node pool
resource "google_container_node_pool" "node_pool" {
  name       = "app-node-pool"
  cluster    = google_container_cluster.gke.id
  node_count = var.node_count

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_size_gb = 50
    disk_type    = "pd-ssd"
  }
}

# Get Google credentials for Kubernetes providers
data "google_client_config" "default" {}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
}

# Configure kubectl provider for YAML application
provider "kubectl" {
  host                   = "https://${google_container_cluster.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}

# Create GitHub Container Registry Secret
resource "kubernetes_secret" "ghcr_secret" {
  metadata {
    name = "ghcr-secret"
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

  depends_on = [google_container_node_pool.node_pool]
}

# Apply frontend YAML manifest 
resource "kubectl_manifest" "frontend_resources" {
  for_each  = { for idx, doc in split("---", file("${path.module}/fe.yaml")) : idx => doc if trimspace(doc) != "" }
  yaml_body = each.value
  
  depends_on = [kubernetes_secret.ghcr_secret]
}