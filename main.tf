provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = file("credentials.json")
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
  name    = "app-node-pool"
  cluster = google_container_cluster.gke.id
  # node_count = var.node_count
  location = google_container_cluster.gke.location

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

  set {
    name  = "controller.config.proxy-read-timeout"
    value = "3600"
  }

  set {
    name  = "controller.config.proxy-send-timeout"
    value = "3600"
  }

  set {
    name  = "controller.config.proxy-body-size"
    value = "20m"
  }

  set {
    name  = "controller.logLevel"
    value = "2"
  }

  # Disable webhook validation temporarily
  set {
    name  = "controller.admissionWebhooks.enabled"
    value = "false"
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

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [google_container_cluster.gke]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  # Server configuration
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  # Disable ingress temporarily
  set {
    name  = "server.ingress.enabled"
    value = "false"
  }

  # Enable insecure mode
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Resource limits for server - reduced
  set {
    name  = "server.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }

  # Controller configuration - reduced
  set {
    name  = "controller.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "128Mi"
  }

  # Redis configuration - reduced
  set {
    name  = "redis.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "redis.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "redis.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "redis.resources.requests.memory"
    value = "64Mi"
  }

  # Repo server configuration - reduced
  set {
    name  = "repoServer.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "repoServer.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "repoServer.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }

  # Enable ApplicationSet controller
  set {
    name  = "applicationSet.enabled"
    value = "true"
  }

  # Enable notifications controller
  set {
    name  = "notifications.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.argocd,
    google_container_node_pool.node_pool,
    helm_release.nginx_ingress
  ]
}

# Install Prometheus
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # Optimize Prometheus server resources
  set {
    name  = "server.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }

  # Optimize node-exporter resources
  set {
    name  = "nodeExporter.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "nodeExporter.resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "nodeExporter.resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "nodeExporter.resources.requests.memory"
    value = "64Mi"
  }

  depends_on = [
    google_container_node_pool.node_pool
  ]
}

# Install Grafana
resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  set {
    name  = "service.port"
    value = "9999"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  # Optimize Grafana resources
  set {
    name  = "resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "resources.limits.memory"
    value = "256Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "resources.requests.memory"
    value = "128Mi"
  }

  depends_on = [
    google_container_node_pool.node_pool,
    helm_release.prometheus
  ]
}

resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = "monitoring"
  }
  type = "Opaque"
  data = {
    admin_password = base64encode(var.grafana_admin_password)
  }
}

locals {
  k8s_manifests = [
    "configmap.yaml",
    "secret.yaml",
    "service-db.yaml",
    "statefulset-db.yaml",

    "be/service-backend.yaml",
    "be/deployment-backend.yaml",

    "fe/service-frontend.yaml",
    "fe/deployment-frontend.yaml",

    "thesis-project.yaml",
    "github-repo-secret.yaml",
  ]
}

resource "kubectl_manifest" "k8s_resources" {
  for_each  = { for idx, file in local.k8s_manifests : file => idx }
  yaml_body = file(each.key)
  depends_on = [
    kubernetes_namespace.my_thesis,
    kubernetes_secret.ghcr_secret,
    # helm_release.nginx_ingress,
  ]
}

# Data source to get the Grafana external IP
data "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = "monitoring"
  }
  depends_on = [helm_release.grafana]
}

resource "kubectl_manifest" "argocd_apps" {
  for_each = {
    backend  = file("${path.module}/be/backend-application.yaml")
    frontend = file("${path.module}/fe/frontend-application.yaml")
  }

  yaml_body = each.value

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.my_thesis
  ]
}

output "cluster_endpoint" {
  value = google_container_cluster.gke.endpoint
}

output "ingress_controller_ip" {
  value       = data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip
  description = "External IP address of the Nginx Ingress Controller"
}

output "grafana_endpoint" {
  value       = "http://${data.kubernetes_service.grafana.metadata[0].name}.${data.kubernetes_service.grafana.metadata[0].namespace}.svc.cluster.local:8888"
  description = "Internal ClusterIP endpoint for Grafana"
}

output "argocd_ingress_ip" {
  value       = data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip
  description = "External IP address for accessing ArgoCD UI"
}
