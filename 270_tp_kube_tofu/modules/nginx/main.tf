# ================================================================
# MODULE NGINX - Application de démonstration Kubernetes
# ================================================================
# Ce module déploie une application nginx sur le cluster Kubernetes
# Il configure plusieurs déploiements avec différentes configurations
# pour démontrer les concepts Kubernetes (services, configmaps, etc.)

# ================================================================
# PROVIDERS REQUIS
# ================================================================

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

# ================================================================
# VARIABLES D'ENTRÉE
# ================================================================

variable "master_ip" {
  description = "IP du nœud master Kubernetes"
  type        = string
}

variable "cluster_name" {
  description = "Nom du cluster Kubernetes"
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes pour le déploiement nginx"
  type        = string
  default     = "default"
}

variable "replicas" {
  description = "Nombre de répliques nginx"
  type        = number
  default     = 3
}

# ================================================================
# RÉCUPÉRATION DE LA CONFIGURATION KUBERNETES
# ================================================================
# Télécharge le kubeconfig depuis le master pour permettre 
# au provider Kubernetes de se connecter au cluster

resource "null_resource" "get_kubeconfig" {
  provisioner "local-exec" {
    command = <<EOT
      mkdir -p ~/.kube
      scp -oStrictHostKeyChecking=no root@${var.master_ip}:/etc/kubernetes/admin.conf ~/.kube/config-${var.cluster_name}
      chmod 600 ~/.kube/config-${var.cluster_name}
    EOT
  }
}

# ================================================================
# CONFIGURATION DU PROVIDER KUBERNETES
# ================================================================
# Utilise le kubeconfig téléchargé pour se connecter au cluster

provider "kubernetes" {
  config_path = "~/.kube/config-${var.cluster_name}"
  depends_on  = [null_resource.get_kubeconfig]
}

# ================================================================
# CRÉATION DU NAMESPACE (SI NÉCESSAIRE)
# ================================================================
# Crée un namespace dédié si différent de "default"

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

# ================================================================
# DÉPLOIEMENT NGINX STANDARD
# ================================================================
# Déploie nginx avec configuration de base pour démonstration

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
          image = "nginx:alpine"  # Image légère Alpine Linux
          name  = "nginx"

          port {
            container_port = 80
            name          = "http"
          }

          # Limites et demandes de ressources pour une gestion optimale
          resources {
            limits = {
              cpu    = var.cpu_limit      # Limite max CPU
              memory = var.memory_limit   # Limite max mémoire
            }
            requests = {
              cpu    = var.cpu_request    # Demande min CPU
              memory = var.memory_request # Demande min mémoire
            }
          }

          # Sonde de santé - redémarre le pod si nginx ne répond plus
          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          # Sonde de disponibilité - retire du load balancer si pas prêt
          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          # Variables d'environnement pour la configuration nginx
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

# ================================================================
# SERVICE CLUSTERIP POUR NGINX
# ================================================================
# Expose nginx en interne dans le cluster sur le port 80

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

# ================================================================
# SERVICE LOADBALANCER POUR NGINX
# ================================================================
# Expose nginx vers l'extérieur via un LoadBalancer
# (si supporté par le cloud provider)

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

# ================================================================
# CONFIGMAP POUR CONTENU PERSONNALISÉ
# ================================================================
# Crée une page d'accueil personnalisée avec les infos du cluster

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

# ================================================================
# DÉPLOIEMENT NGINX AVEC CONTENU PERSONNALISÉ
# ================================================================
# Déploie nginx avec une page d'accueil personnalisée via ConfigMap

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

          # Monte le ConfigMap comme volume pour remplacer le contenu par défaut
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

        # Volume basé sur le ConfigMap contenant la page personnalisée
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

# ================================================================
# SERVICE POUR LE DÉPLOIEMENT PERSONNALISÉ
# ================================================================
# Expose le nginx personnalisé sur le port 8080

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