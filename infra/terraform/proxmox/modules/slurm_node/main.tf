locals {
  vm_name = format("%s-%s-%02d", var.cluster_name, var.role, var.index)
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = local.vm_name
  node_name = var.target_node_name
  keyboard_layout = var.keyboard_layout

  clone {
    vm_id = var.vm_template_id
    full  = true
  }

  cpu {
    cores = var.cpu
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.vm_datastore_id
    interface    = "virtio0"
    size         = 25
  }

  network_device {
    bridge = var.vm_network_bridge
    model  = "virtio"
    mac_address = var.mac_address != "" ? var.mac_address : null
  }

  initialization {
    user_account {
      username = "debian"
      password = var.vm_user_password
      keys     = [var.ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  agent {
    enabled = true
  }
}
