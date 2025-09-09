# Create VPC
resource "google_compute_network" "dev_vpc" {
  name                    = "dev-vpc"
  auto_create_subnetworks = false
}

# Create Cloud Router
resource "google_compute_router" "router" {
  name    = "${google_compute_network.dev_vpc.name}-router"
  network = google_compute_network.dev_vpc.name
}

# Create Cloud NAT (for private subnet)
resource "google_compute_router_nat" "nat" {
  name                               = "${google_compute_network.dev_vpc.name}-nat"
  router                             = google_compute_router.router.name
  nat_ip_allocate_option             = "AUTO_ONLY"                     # Ephemaral public ip (GCP give public ip for NAT gateway)
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" # This NAT gateway cover all subnets in VPC (let cloud nat available to use with all subnets in this vpc and all of ip range is in subnets)
}

# Create public-subnet
resource "google_compute_subnetwork" "public_subnet" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.dev_vpc.id
}

# Create private-subnet
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.dev_vpc.id
}

# Create firewall (allow iap to vm)
resource "google_compute_firewall" "allow_iap_ssh_to_vm" {
  name    = "${google_compute_network.dev_vpc.name}-allow-iap-to-vm"
  network = google_compute_network.dev_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["public", "private"]
}

# Create firewall (allow user to http)
resource "google_compute_firewall" "allow_user_to_http" {
  name    = "${google_compute_network.dev_vpc.name}-allow-user-to-http"
  network = google_compute_network.dev_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["public"]
}

# Create firewall (allow_frontend_access_backend)
resource "google_compute_firewall" "allow_frontend_access_backend" {
  name    = "${google_compute_network.dev_vpc.name}-allow-frontend-access-backend"
  network = google_compute_network.dev_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "22"]
  }
  source_tags = ["public"]
  target_tags = ["private"]
}

# Create frontend vm in public-subnet
resource "google_compute_instance" "frontend_vm" {
  name         = "frontend-vm"
  machine_type = "e2-micro"
  zone         = "asia-southeast1-a"
  tags         = ["public"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    access_config { # Add public ip (Ephemeral public ip)
    }
  }
}


# Create backend vm in public-subnet
resource "google_compute_instance" "backend_vm" {
  name         = "backend-vm"
  machine_type = "e2-micro"
  zone         = "asia-southeast1-a"
  tags         = ["private"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
  }
}

