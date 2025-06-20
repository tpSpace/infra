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
    min_node_count = 1
    max_node_count = 6
  }
  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    machine_type = "e2-medium" # 2 vCPU, 8GB RAM
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_size_gb = 30
    disk_type    = "pd-ssd"
    image_type   = "COS_CONTAINERD"
  }

  depends_on = [google_container_cluster.gke]
}

# Wait for cluster to be fully ready
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [google_container_node_pool.node_pool]
  create_duration = "60s"
}

data "google_client_config" "default" {
  provider = google
}

provider "kubernetes" {
  # Use config file primarily
  config_path    = "~/.kube/config"
  config_context = "gke_${var.project_id}_${var.region}_${var.cluster_name}"
}

provider "kubectl" {
  # Use config file primarily
  config_path      = "~/.kube/config"
  config_context   = "gke_${var.project_id}_${var.region}_${var.cluster_name}"
  load_config_file = true
}

provider "helm" {
  kubernetes {
    # Use config file primarily
    config_path    = "~/.kube/config"
    config_context = "gke_${var.project_id}_${var.region}_${var.cluster_name}"
  }
}

resource "kubernetes_namespace" "my_thesis" {
  metadata {
    name = "my-thesis"
  }
  depends_on = [
    time_sleep.wait_for_cluster
  ]
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

  depends_on = [
    kubernetes_namespace.my_thesis,
    time_sleep.wait_for_cluster
  ]
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
    time_sleep.wait_for_cluster
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

# Wait for ingress controller to get external IP
resource "time_sleep" "wait_for_ingress_ip" {
  depends_on      = [data.kubernetes_service.ingress_controller]
  create_duration = "30s"
}

# Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [
    time_sleep.wait_for_cluster
  ]
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

  # Resource limits for server - Increased for stability
  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "256Mi"
  }

  # Controller configuration - Increased memory for stability
  set {
    name  = "controller.resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "2Gi"
  }

  set {
    name  = "controller.resources.requests.cpu"
    value = "200m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  # Redis configuration - conservative
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

  # Repo server configuration - Increase memory
  set {
    name  = "repoServer.resources.limits.cpu"
    value = "200m" # Increase from 100m
  }

  set {
    name  = "repoServer.resources.limits.memory"
    value = "1Gi"
  }

  set {
    name  = "repoServer.resources.requests.cpu"
    value = "100m" # Increase from 50m
  }

  set {
    name  = "repoServer.resources.requests.memory"
    value = "512Mi"
  }

  # Enable ApplicationSet controller
  set {
    name  = "applicationSet.enabled"
    value = "true"
  }

  # Set ArgoCD admin password (bcrypt hash)
  set {
    name  = "server.adminPassword"
    value = var.argocd_admin_password
  }

  depends_on = [
    kubernetes_namespace.argocd,
    time_sleep.wait_for_cluster
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
    value = "LoadBalancer"
  }

  # Conservative Prometheus server resources
  set {
    name  = "server.resources.limits.cpu"
    value = "200m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }

  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "256Mi"
  }

  # Conservative node-exporter resources
  set {
    name  = "nodeExporter.resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "nodeExporter.resources.limits.memory"
    value = "64Mi"
  }

  set {
    name  = "nodeExporter.resources.requests.cpu"
    value = "25m"
  }

  set {
    name  = "nodeExporter.resources.requests.memory"
    value = "32Mi"
  }

  depends_on = [
    time_sleep.wait_for_cluster
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
    value = "LoadBalancer"
  }

  set {
    name  = "service.port"
    value = "9999"
  }

  set {
    name  = "persistence.enabled"
    value = "false"
  }

  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  # Conservative Grafana resources
  set {
    name  = "resources.limits.cpu"
    value = "100m"
  }

  set {
    name  = "resources.limits.memory"
    value = "128Mi"
  }

  set {
    name  = "resources.requests.cpu"
    value = "50m"
  }

  set {
    name  = "resources.requests.memory"
    value = "64Mi"
  }

  depends_on = [
    time_sleep.wait_for_cluster,
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

  depends_on = [
    helm_release.prometheus,
    helm_release.grafana
  ]
}

locals {
  k8s_manifests = [
    "configmap.yaml",
    "secret.yaml",

    "postgres-0/service-db.yaml",
    "postgres-0/statefulset-db.yaml",
    "postgres-0/postgres-init-configmap.yaml",

    "postgres-1/service-db.yaml",
    "postgres-1/statefulset-db.yaml",
    "postgres-1/postgres-llm-secret.yaml",

    "rabbitmq/rabbitmq-secret.yaml",
    "rabbitmq/rabbitmq-configmap.yaml",
    "rabbitmq/rabbit.yaml",
    "rabbitmq/rabbitmq-service.yaml",
    "rabbitmq/rabbitmq-job.yaml",

    "ingress.yaml",
    "argocd/thesis-project.yaml",
  ]
}

resource "kubectl_manifest" "k8s_resources" {
  for_each = { for idx, file in local.k8s_manifests : file => idx }
  yaml_body = each.key == "configmap.yaml" ? templatefile(each.key, {
    ingress_ip  = data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip
    db_username = var.db_username
    db_password = var.db_password
    db_name     = var.db_name
  }) : file(each.key)
  depends_on = [
    kubernetes_namespace.my_thesis,
    kubernetes_secret.ghcr_secret,
    helm_release.nginx_ingress,
    time_sleep.wait_for_ingress_ip
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

# Data source to get the Prometheus external IP
data "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus-server"
    namespace = "monitoring"
  }
  depends_on = [helm_release.prometheus]
}

resource "kubectl_manifest" "argocd_apps" {
  for_each = {
    backend  = file("${path.module}/be/backend-application.yaml")
    frontend = file("${path.module}/fe/frontend-application.yaml")
  }

  yaml_body = each.value

  depends_on = [
    helm_release.argocd,
    kubernetes_namespace.my_thesis,
    kubectl_manifest.github_repo_creds,
    kubectl_manifest.argocd_fe_repo_creds,
    kubectl_manifest.argocd_be_repo_creds,
    kubectl_manifest.argocd_ssh_known_hosts,
    kubectl_manifest.k8s_resources
  ]
}

# SSH known hosts secret for ArgoCD
resource "kubectl_manifest" "argocd_ssh_known_hosts" {
  yaml_body = file("${path.module}/argocd/ssh-known-hosts-secret.yaml")

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.argocd
  ]
}

# GitHub repository credentials secret for ArgoCD (SSH)
resource "kubectl_manifest" "github_repo_creds" {
  yaml_body = file("${path.module}/argocd/github-ssh-repo-secret.yaml")

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.argocd
  ]
}

# SSH repository credentials for application repos
resource "kubectl_manifest" "argocd_fe_repo_creds" {
  yaml_body = file("${path.module}/argocd/argocd-fe-repo-config.yaml")

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.argocd
  ]
}

resource "kubectl_manifest" "argocd_be_repo_creds" {
  yaml_body = file("${path.module}/argocd/argocd-be-repo-config.yaml")

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.argocd
  ]
}

# Alternative approach: Dedicated ConfigMap resource
# resource "kubernetes_config_map" "app_config" {
#   metadata {
#     name      = "app-config"
#     namespace = "my-thesis"
#   }
#
#   data = {
#     DATABASE_HOST               = "postgres"
#     DATABASE_PORT              = "5432"
#     DATASOURCE_URL             = "postgresql://${var.db_username}:${var.db_password}@postgres-headless.my-thesis.svc.cluster.local:5432/${var.db_name}?sslmode=disable"
#     ROLE_ADMIN_CODE            = "1"
#     ROLE_TEACHER_CODE          = "2"
#     ROLE_STUDENT_CODE          = "3"
#     CLIENT_ORIGIN              = "http://${data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip}/app"
#     NEXT_PUBLIC_GRAPHQL_URI    = "http://${data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip}/api/graphql"
#     BACKEND_URL                = "http://${data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip}/api/graphql"
#   }
#
#   depends_on = [
#     kubernetes_namespace.my_thesis,
#     data.kubernetes_service.ingress_controller
#   ]
# }

output "cluster_endpoint" {
  value = google_container_cluster.gke.endpoint
}

output "ingress_controller_ip" {
  value       = data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip
  description = "External IP address of the Nginx Ingress Controller"
}

output "grafana_endpoint" {
  value       = "http://${data.kubernetes_service.grafana.status.0.load_balancer.0.ingress.0.ip}:9999"
  description = "External LoadBalancer endpoint for Grafana"
}

output "prometheus_endpoint" {
  value       = "http://${data.kubernetes_service.prometheus.status.0.load_balancer.0.ingress.0.ip}"
  description = "External LoadBalancer endpoint for Prometheus"
}

output "argocd_ingress_ip" {
  value       = data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip
  description = "External IP address for accessing ArgoCD UI"
}

output "application_urls" {
  value = {
    frontend_url   = "http://${data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip}/app"
    backend_url    = "http://${data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip}/api"
    root_url       = "http://${data.kubernetes_service.ingress_controller.status.0.load_balancer.0.ingress.0.ip}"
    grafana_url    = "http://${data.kubernetes_service.grafana.status.0.load_balancer.0.ingress.0.ip}:9999"
    prometheus_url = "http://${data.kubernetes_service.prometheus.status.0.load_balancer.0.ingress.0.ip}"
  }
  description = "URLs to access your applications and monitoring tools via LoadBalancer"
}
