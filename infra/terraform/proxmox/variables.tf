variable "cluster_name" {
  type        = string
  description = "Nom logique du cluster Slurm."
  default     = "autoslurm"
}

variable "proxmox_api_url" {
  type        = string
  description = "URL API Proxmox."
}

variable "proxmox_api_token" {
  type        = string
  description = "Token API Proxmox."
  sensitive   = true
}

variable "proxmox_insecure" {
  type        = bool
  description = "Autorise TLS non verifie."
  default     = true
}

variable "target_node_name" {
  type        = string
  description = "Noeud Proxmox cible."
}

variable "vm_template_id" {
  type        = number
  description = "ID de template VM Debian 13."
}

variable "vm_datastore_id" {
  type        = string
  description = "Datastore Proxmox pour les disques."
}

variable "vm_network_bridge" {
  type        = string
  description = "Bridge reseau Proxmox."
  default     = "vmbr0"
}

variable "ssh_public_key" {
  type        = string
  description = "Cle SSH publique injectee dans la VM."
}

variable "controller_cpu" {
  type        = number
  default     = 2
}

variable "controller_memory_mb" {
  type        = number
  default     = 4096
}

variable "compute_cpu" {
  type        = number
  default     = 2
}

variable "compute_memory_mb" {
  type        = number
  default     = 4096
}

variable "initial_compute_count" {
  type        = number
  description = "Nombre initial de noeuds compute."
  default     = 1
}
