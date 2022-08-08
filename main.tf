provider "google" {
  credentials = file(var.credentials_file)
  project     = var.project
  region      = var.region
  zone        = var.zone
}
// initializing google cloud provider with provided via variables requirements and specifications
resource "google_compute_instance" "default" {
  name         = "ansible-vm"
  machine_type = "f1-micro"
  tags         = ["ssh"]
  // setting up the VM name and type
  metadata = {
    enable-oslogin = "FALSE"
    ssh-keys       = join("", ["ansible:", file(var.ssh_key_file)])
  }
  //making sure our ssh-key created in advance is passed to the vm
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }
  // setting up the specific image for vm
  metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq python3"
  // installing python on vm, required for ansible to complete the task
  network_interface {
    network = "default"
    // connecting the vm to default vpc network with default access config
    access_config {
    }
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${google_compute_instance.default.network_interface.0.access_config.0.nat_ip}, ${var.ansible_playbook} -v"
  }
}
//passing via cli the command for ansible on localhost to use the playbook specified in variables on a VM through its ip address
resource "google_compute_firewall" "ssh" {
  name = "allow-ssh"
  allow {
    ports    = ["22"]
    protocol = "tcp"
  }
  direction     = "INGRESS"
  network       = "default"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh"]
}
//opening the ssh port on a VM to allow ansible to connect to it
resource "google_compute_firewall" "ansible-vm" {
  name    = "ansible-vm-apache"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  source_ranges = ["0.0.0.0/0"]
}
//opening default 80 port to access generated web-server page on VM
resource "google_compute_firewall" "http-outbound" {
  name    = "allow-outbound-rules"
  network = "default"

  allow {
    protocol = "tcp"
  }
  direction     = "EGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]
}
//allowing outgoing connection for the VM
output "Web-server-URL" {
  value = join("", ["http://", google_compute_instance.default.network_interface.0.access_config.0.nat_ip, ":80"])
}
//Making terraform pring the URL of web-server with new VM ip address after the ansible task is done and terraform has finished its creation.