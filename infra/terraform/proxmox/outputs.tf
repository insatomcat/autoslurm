output "controller" {
  value = {
    name = module.controller.vm_name
    ipv4 = module.controller.ipv4
  }
}

output "compute_nodes" {
  value = [
    for node in module.compute_nodes : {
      name = node.vm_name
      ipv4 = node.ipv4
    }
  ]
}

output "cluster_inventory" {
  value = {
    controller = {
      name = module.controller.vm_name
      ipv4 = module.controller.ipv4
    }
    compute_nodes = [
      for node in module.compute_nodes : {
        name = node.vm_name
        ipv4 = node.ipv4
      }
    ]
  }
}
