module "controller" {
  source = "./modules/slurm_node"

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
}

module "compute_nodes" {
  source = "./modules/slurm_node"
  count  = var.initial_compute_count

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
}
