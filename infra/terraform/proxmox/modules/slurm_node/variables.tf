variable "cluster_name" {
  type = string
}

variable "role" {
  type = string
}

variable "index" {
  type = number
}

variable "target_node_name" {
  type = string
}

variable "vm_template_id" {
  type = number
}

variable "vm_datastore_id" {
  type = string
}

variable "vm_network_bridge" {
  type = string
}

variable "cpu" {
  type = number
}

variable "memory_mb" {
  type = number
}

variable "ssh_public_key" {
  type = string
}

variable "vm_user_password" {
  type      = string
  sensitive = true
}

variable "keyboard_layout" {
  type = string
}

variable "mac_address" {
  type    = string
  default = ""
}
