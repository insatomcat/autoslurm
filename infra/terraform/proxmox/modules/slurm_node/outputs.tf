output "vm_name" {
  value = proxmox_virtual_environment_vm.this.name
}

output "ipv4" {
  value = try(
    proxmox_virtual_environment_vm.this.ipv4_addresses[1][0],
    null
  )
}
