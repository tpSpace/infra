provider "google" {
  project = var.project_id
  region  = var.region
}

terraform {
  required_version = ">= 1.11.4"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.29.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9.0"
    }
  }
}

# GKE Cluster
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = var.node_count
  deletion_protection      = false
}

# Node Pool
resource "google_container_node_pool" "node_pool" {
  name       = "app-node-pool"
  cluster    = google_container_cluster.gke.id
  # node_count = var.node_count
  location   = google_container_cluster.gke.location
  
  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }
  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_size_gb = 30
    disk_type    = "pd-ssd"
    image_type   = "COS_CONTAINERD"
  }

  depends_on = [google_container_cluster.gke]
}

data "google_client_config" "default" {
  provider = google
}

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

provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  }
}

resource "kubernetes_namespace" "my_thesis" {
  metadata {
    name = "my-thesis"
  }
  depends_on = [google_container_cluster.gke]  
}

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

# Install Nginx Ingress Controller
resource "helm_release" "nginx_ingress" {
  name             = "nginx-ingress"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  
  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }
  
  depends_on = [
    google_container_node_pool.node_pool
  ]
}

# Data source to get the Ingress Controller's external IP
data "kubernetes_service" "ingress_controller" {
  metadata {
    name      = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx_ingress]
}

locals {
  k8s_manifests = [
    "configmap.yaml",
    "secret.yaml",
    "service-db.yaml",
    "statefulset-db.yaml",
    "service-backend.yaml",
    # "argocd-install.yaml",
    "deployment-backend.yaml",
    "service-frontend.yaml",
    "ingress.yaml",
    "deployment-frontend.yaml",
  ]
}

resource "kubectl_manifest" "k8s_resources" {
  for_each  = { for idx, file in local.k8s_manifests : file => idx }
  yaml_body = file(each.key)
  depends_on = [
    kubernetes_namespace.my_thesis,
    kubernetes_secret.ghcr_secret,
    helm_release.nginx_ingress,
  ]
}

output "cluster_endpoint" {
  value = google_container_cluster.gke.endpoint
}

output "ingress_controller_ip" {
  value       = data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip
  description = "External IP address of the Nginx Ingress Controller"
}