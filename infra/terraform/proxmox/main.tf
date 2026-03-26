locals {
  additional_compute_count = var.colocate_controller_and_first_compute ? max(var.initial_compute_count - 1, 0) : var.initial_compute_count
}

module "controller" {
  source = "./modules/slurm_node"
  count  = var.colocate_controller_and_first_compute ? 0 : 1

  cluster_name      = var.cluster_name
  role              = "controller"
  index             = 0
  target_node_name  = var.target_node_name
  vm_template_id    = var.vm_template_id
  vm_datastore_id   = var.vm_datastore_id
  vm_network_bridge = var.vm_network_bridge
  cpu               = var.controller_cpu
  memory_mb         = var.controller_memory_mb
  ssh_public_key    = var.ssh_public_key
  vm_user_password  = var.vm_user_password
  keyboard_layout   = var.vm_keyboard_layout
}

module "controller_compute" {
  source = "./modules/slurm_node"
  count  = var.colocate_controller_and_first_compute ? 1 : 0

  cluster_name      = var.cluster_name
  role              = "controller-compute"
  index             = 0
  target_node_name  = var.target_node_name
  vm_template_id    = var.vm_template_id
  vm_datastore_id   = var.vm_datastore_id
  vm_network_bridge = var.vm_network_bridge
  cpu               = max(var.controller_cpu, var.compute_cpu)
  memory_mb         = max(var.controller_memory_mb, var.compute_memory_mb)
  ssh_public_key    = var.ssh_public_key
  vm_user_password  = var.vm_user_password
  keyboard_layout   = var.vm_keyboard_layout
}

module "compute_nodes" {
  source = "./modules/slurm_node"
  count  = local.additional_compute_count

  cluster_name      = var.cluster_name
  role              = "compute"
  index             = count.index + 1
  target_node_name  = var.target_node_name
  vm_template_id    = var.vm_template_id
  vm_datastore_id   = var.vm_datastore_id
  vm_network_bridge = var.vm_network_bridge
  cpu               = var.compute_cpu
  memory_mb         = var.compute_memory_mb
  ssh_public_key    = var.ssh_public_key
  vm_user_password  = var.vm_user_password
  keyboard_layout   = var.vm_keyboard_layout
}
