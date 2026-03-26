locals {
  controller_node = var.colocate_controller_and_first_compute ? {
    name = module.controller_compute[0].vm_name
    ipv4 = module.controller_compute[0].ipv4
    } : {
    name = module.controller[0].vm_name
    ipv4 = module.controller[0].ipv4
  }
}

output "controller" {
  value = local.controller_node
}

output "compute_nodes" {
  value = concat(
    [
      for node in module.controller_compute : {
        name = node.vm_name
        ipv4 = node.ipv4
      }
    ],
    [
      for node in module.compute_nodes : {
        name = node.vm_name
        ipv4 = node.ipv4
      }
    ]
  )
}

output "cluster_inventory" {
  value = {
    controller = local.controller_node
    compute_nodes = concat(
      [
        for node in module.controller_compute : {
          name = node.vm_name
          ipv4 = node.ipv4
        }
      ],
      [
        for node in module.compute_nodes : {
          name = node.vm_name
          ipv4 = node.ipv4
        }
      ]
    )
  }
}
