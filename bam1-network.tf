# BAM 1 — Custom VPC, subnet, and firewall
# The VM in bam1-vm.tf uses this network instead of "default"

resource "google_compute_network" "custom_vpc" {
  name                    = "custom-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "custom_subnet" {
  name          = "custom-subnet-us-central1"
  ip_cidr_range = "10.10.0.0/24"
  region        = "us-central1"
  network       = google_compute_network.custom_vpc.id
}

# Allow HTTP — targets VMs tagged "custom-web"
resource "google_compute_firewall" "allow_http" {
  name    = "custom-vpc-allow-http"
  network = google_compute_network.custom_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags   = ["custom-web"]
  source_ranges = ["0.0.0.0/0"]
}

# Allow SSH — needed to connect to the VM for debugging
resource "google_compute_firewall" "allow_ssh" {
  name    = "custom-vpc-allow-ssh"
  network = google_compute_network.custom_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = ["custom-web"]
  source_ranges = ["0.0.0.0/0"]
}
resource "google_compute_subnetwork" "custom_subnet_east" {
  name          = "custom-subnet-us-east1"
  ip_cidr_range = "10.10.1.0/24"
  region        = "us-east1"
  network       = google_compute_network.custom_vpc.id
}
