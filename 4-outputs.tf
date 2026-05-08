# Outputs for the base VM
# Run `terraform output` after apply to see these values

output "internal_ip" {
  value = google_compute_instance.vm.network_interface[0].network_ip
}

output "external_ip" {
  value = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

# name — the label you set, shown in the Console
output "vm_name" {
  value = google_compute_instance.vm.name
}

# id — fully-qualified GCP resource identifier, used by Terraform state
# format: projects/{project}/zones/{zone}/instances/{name}
output "vm_id" {
  value = google_compute_instance.vm.id
}

# self_link — full REST API URL, used when other GCP resources need to reference this VM
output "vm_self_link" {
  value = google_compute_instance.vm.self_link
}
