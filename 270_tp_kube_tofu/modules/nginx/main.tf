terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

# Variables d'entrée
variable "master_ip" {
  description = "IP du nœud master Kubernetes"
  type        = string
}

variable "cluster_name" {
  description = "Nom du cluster Kubernetes"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for nginx deployment"
  type        = string
  default     = "default"
}

variable "replicas" {
  description = "Number of nginx replicas"
  type        = number
  default     = 3
}

# Récupération du kubeconfig depuis le master
resource "null_resource" "get_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.kube
      scp -oStrictHostKeyChecking=no root@${var.master_ip}:/etc/kubernetes/admin.conf ~/.kube/config-${var.cluster_name}
      chmod 600 ~/.kube/config-${var.cluster_name}
    EOT
  }
}

# Configuration du provider Kubernetes
provider "kubernetes" {
  config_path = "~/.kube/config-${var.cluster_name}"
  depends_on  = [null_resource.get_kubeconfig]
}

# Namespace dédié (optionnel)
resource "kubernetes_namespace" "nginx_namespace" {
  count = var.namespace != "default" ? 1 : 0
  
  metadata {
    name = var.namespace
    labels = {
      managed-by = "terraform"
      app        = "nginx"
    }
  }
}

# Déploiement nginx
resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = var.namespace
    labels = {
      app         = "nginx"
      managed-by  = "terraform"
      environment = "demo"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "nginx"

          port {
            container_port = 80
            name          = "http"
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          # Variables d'environnement
          env {
            name  = "NGINX_HOST"
            value = "localhost"
          }
          
          env {
            name  = "NGINX_PORT"
            value = "80"
          }
        }
      }
    }
  }
}

# Service pour exposer nginx
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = var.namespace
    labels = {
      app = "nginx"
    }
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Service LoadBalancer (si supporté par le cloud provider)
resource "kubernetes_service" "nginx_lb" {
  metadata {
    name      = "nginx-loadbalancer"
    namespace = var.namespace
    labels = {
      app = "nginx"
    }
    annotations = {
      "service.beta.kubernetes.io/do-loadbalancer-name" = "nginx-lb-${var.cluster_name}"
    }
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

# ConfigMap pour une page d'accueil personnalisée
resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-html-config"
    namespace = var.namespace
  }

  data = {
    "index.html" = templatefile("${path.module}/templates/index.html", {
      cluster_name = var.cluster_name
      replicas     = var.replicas
      namespace    = var.namespace
    })
  }
}

# Déploiement avec page personnalisée
resource "kubernetes_deployment" "nginx_custom" {
  metadata {
    name      = "nginx-custom"
    namespace = var.namespace
    labels = {
      app         = "nginx-custom"
      managed-by  = "terraform"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "nginx-custom"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-custom"
        }
      }

      spec {
        container {
          image = "nginx:alpine"
          name  = "nginx"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "html-content"
            mount_path = "/usr/share/nginx/html"
            read_only  = true
          }

          resources {
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
          }
        }

        volume {
          name = "html-content"
          config_map {
            name = kubernetes_config_map.nginx_config.metadata[0].name
          }
        }
      }
    }
  }
}

# Service pour le déploiement custom
resource "kubernetes_service" "nginx_custom" {
  metadata {
    name      = "nginx-custom-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "nginx-custom"
    }

    port {
      port        = 8080
      target_port = 80
    }

    type = "ClusterIP"
  }
}