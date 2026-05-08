# Base VM — CentOS Stream 10, 100GB disk, default VPC
# http-server tag opens port 80 via the default VPC's built-in firewall rule

resource "google_compute_instance" "vm" {
  name         = "centos-web-vm"
  machine_type = "n2-standard-2"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      # Family reference always pulls the latest CentOS Stream 10 image
      image = "projects/centos-cloud/global/images/family/centos-stream-10"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"

    access_config {
      # Empty block = GCP assigns an ephemeral external IP
    }
  }

  tags = ["http-server"]

  metadata = {
    startup-script = file("${path.module}/startup.sh")
  }
}
