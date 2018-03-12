// Configure the Google Cloud provider
provider "google" {
  credentials = "${file("hello-world-pompei-1712e59c82fd.json")}"
  project     = "hello-world-pompei"
  region      = "us-east1-b"
}

resource "google_compute_instance" "default" {
  name         = "instance-terraform"
  machine_type = "f1-micro"
  zone         = "us-east1-b"

  tags = ["rodrigo", "pompei"]

  boot_disk {
    initialize_params {
      image = "centos-cloud/centos-7"
    }
  }

  // Local SSD disk
//   disks {
//      autoDelete = "true"
//      boot: = "true"
//      deviceName = "instance-2"
//      index = "0"
//      interface = "SCSI"
//      kind = "compute#attachedDisk"
//     licenses = [
//        "projects/centos-cloud/global/licenses/centos-7"
//      ]
//      mode = "READ_WRITE"
//      source ="projects/hello-world-pompei/zones/us-east1-b/disks/instance-2"
//      type = "PERSISTENT"
//    }

//  scratch_disk {
//  }
//  disk {
//  }

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  metadata {
    rodr = "pomps"
  }

  metadata_startup_script = "echo hi > /test_pomps.txt"

  service_account {
    scopes = ["userinfo-email", "compute-ro", "storage-ro"]
  }
}
