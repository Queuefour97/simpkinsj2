# BAM 2 — Instance template + VM provisioned from that template
#
# google_compute_instance_from_template is the correct resource here —
# NOT google_compute_instance. The latter does not support source_instance_template.
# This resource inherits all config from the template; only name and zone are required.

resource "google_compute_instance_template" "web_template" {
  name_prefix  = "web-template-"
  machine_type = "n2-standard-2"
  region       = "us-east1"

  # Templates use `disk` block, not `boot_disk` like google_compute_instance
  disk {
    source_image = "projects/centos-cloud/global/images/family/centos-stream-10"
    auto_delete  = true
    boot         = true
    disk_size_gb = 100
    disk_type    = "pd-balanced"
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.custom_subnet_east.id

    access_config {
      # Ephemeral external IP
    }
  }

  tags = ["custom-web"]

  metadata = {
    startup-script = file("${path.module}/startup.sh")
  }

  # Templates are immutable — create new before destroying old
  # name_prefix guarantees a unique name on each apply
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_from_template" "vm_bam2" {
  name                     = "centos-web-vm-bam2"
  zone                     = "us-east1-b"
  source_instance_template = google_compute_instance_template.web_template.self_link
}

output "vm_bam2_ips" {
  value = {
    internal_ip = google_compute_instance_from_template.vm_bam2.network_interface[0].network_ip
    external_ip = google_compute_instance_from_template.vm_bam2.network_interface[0].access_config[0].nat_ip
  }
}

output "instance_template_self_link" {
  value = google_compute_instance_template.web_template.self_link
}