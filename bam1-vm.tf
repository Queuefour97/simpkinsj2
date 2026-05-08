# BAM 1 — VM on custom VPC
# Uses network/subnet from bam1-network.tf
# "custom-web" tag is what the firewall rules in bam1-network.tf target
# Comment out the VM in 3-main.tf before applying to avoid resource conflicts

resource "google_compute_instance" "vm_bam1" {
  name         = "centos-web-vm-bam1"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "projects/centos-cloud/global/images/family/centos-stream-10"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.custom_vpc.id
    subnetwork = google_compute_subnetwork.custom_subnet.id

    access_config {
      # Ephemeral external IP
    }
  }

  tags = ["custom-web"]

  metadata = {
    startup-script = file("${path.module}/startup.sh")
  }
}

# Single output block returning both IPs as a map
# Access with: terraform output -json vm_bam1_ips
output "vm_bam1_ips" {
  value = {
    internal_ip = google_compute_instance.vm_bam1.network_interface[0].network_ip
    external_ip = google_compute_instance.vm_bam1.network_interface[0].access_config[0].nat_ip
  }
}
