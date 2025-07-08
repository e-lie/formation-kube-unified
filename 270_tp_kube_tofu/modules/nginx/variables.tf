# Variables pour le module nginx

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
  
  validation {
    condition     = var.replicas > 0 && var.replicas <= 10
    error_message = "Replicas must be between 1 and 10."
  }
}

variable "image_tag" {
  description = "Nginx image tag"
  type        = string
  default     = "alpine"
}

variable "cpu_limit" {
  description = "CPU limit for nginx containers"
  type        = string
  default     = "500m"
}

variable "memory_limit" {
  description = "Memory limit for nginx containers"
  type        = string
  default     = "512Mi"
}

variable "cpu_request" {
  description = "CPU request for nginx containers"
  type        = string
  default     = "250m"
}

variable "memory_request" {
  description = "Memory request for nginx containers"
  type        = string
  default     = "256Mi"
}