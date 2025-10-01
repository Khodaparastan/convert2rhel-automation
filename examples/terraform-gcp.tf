#
# Convert2RHEL Automation - Google Cloud Platform (GCP) Example
#
# This Terraform configuration demonstrates how to use convert2rhel-automation
# to convert GCP VM instances running CentOS to RHEL.
#
# Requirements:
#   - Terraform 1.0+
#   - GCP credentials configured (gcloud auth application-default login)
#   - GCP project with Compute Engine API enabled
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply -var-file="gcp.tfvars"
#

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# ============================================================================
# Variables
# ============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for instances"
  type        = string
  default     = "us-central1-a"
}

variable "rh_org_id" {
  description = "Red Hat organization ID"
  type        = string
  sensitive   = true
}

variable "rh_activation_key" {
  description = "Red Hat activation key"
  type        = string
  sensitive   = true
}

variable "instance_count" {
  description = "Number of instances to convert"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "n1-standard-2"  # 2 vCPUs, 7.5 GB memory
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "default"
}

variable "ssh_user" {
  description = "SSH username for instances"
  type        = string
  default     = "centos"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "centos_image" {
  description = "CentOS image to use (will be converted to RHEL)"
  type        = string
  # CentOS 8 Stream (official)
  default     = "centos-cloud/centos-stream-8"
}

variable "run_analysis_only" {
  description = "Only run analysis without conversion"
  type        = bool
  default     = false
}

variable "auto_reboot" {
  description = "Automatically reboot after conversion"
  type        = bool
  default     = false
}

variable "script_url" {
  description = "URL to convert2rhel-setup script"
  type        = string
  default     = "https://raw.githubusercontent.com/khodaparastan/convert2rhel-automation/main/convert2rhel-setup"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default = {
    project     = "rhel-conversion"
    managed-by  = "terraform"
    environment = "migration"
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ============================================================================
# Data Sources
# ============================================================================

data "google_compute_image" "centos" {
  family  = "centos-stream-8"
  project = "centos-cloud"
}

data "google_compute_network" "vpc" {
  name = var.network_name
}

data "google_compute_subnetwork" "subnet" {
  name   = var.subnet_name
  region = var.region
}

# ============================================================================
# Firewall Rules
# ============================================================================

resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh-convert2rhel-${random_id.suffix.hex}"
  network = data.google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Restrict this in production!
  target_tags   = ["convert2rhel"]

  description = "Allow SSH access for convert2rhel automation"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================================
# Compute Instances
# ============================================================================

resource "google_compute_instance" "conversion_target" {
  count = var.instance_count

  name         = "centos-to-rhel-${count.index + 1}-${random_id.suffix.hex}"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["convert2rhel"]

  boot_disk {
    initialize_params {
      image = var.centos_image != "" ? var.centos_image : data.google_compute_image.centos.self_link
      size  = 20  # GB
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = data.google_compute_network.vpc.self_link
    subnetwork = data.google_compute_subnetwork.subnet.self_link

    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  labels = merge(
    var.labels,
    {
      conversion-status = "pending"
    }
  )

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [metadata]
  }
}

# Wait for instances to be ready
resource "null_resource" "wait_for_instances" {
  count = var.instance_count

  depends_on = [google_compute_instance.conversion_target]

  provisioner "local-exec" {
    command = "sleep 60"
  }
}

# ============================================================================
# Conversion Automation
# ============================================================================

# Run convert2rhel analysis
resource "null_resource" "convert2rhel_analysis" {
  count = var.instance_count

  depends_on = [
    null_resource.wait_for_instances,
    google_compute_firewall.ssh
  ]

  connection {
    type        = "ssh"
    host        = google_compute_instance.conversion_target[count.index].network_interface[0].access_config[0].nat_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  # Download and setup script
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '========================================='",
      "echo 'Convert2RHEL Setup - Analysis Phase'",
      "echo 'Instance: ${google_compute_instance.conversion_target[count.index].name}'",
      "echo '========================================='",
      "sudo yum install -y wget curl",
      "wget -q -O /tmp/convert2rhel-setup ${var.script_url}",
      "chmod +x /tmp/convert2rhel-setup",
      "echo 'Script downloaded successfully'",
    ]
  }

  # Run analysis
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo 'Running pre-conversion analysis...'",
      "sudo /tmp/convert2rhel-setup \\",
      "  --org-id ${var.rh_org_id} \\",
      "  --activation-key ${var.rh_activation_key} \\",
      "  --analyze-only \\",
      "  --assume-yes",
      "echo 'Analysis completed'",
    ]
  }

  # Save analysis results locally
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ./conversion-logs
      gcloud compute ssh ${var.ssh_user}@${google_compute_instance.conversion_target[count.index].name} \
        --zone=${var.zone} \
        --command="sudo cat /var/log/convert2rhel-setup-analysis.log" \
        > ./conversion-logs/gcp-analysis-instance-${count.index + 1}.log || true
    EOT
  }

  triggers = {
    instance_id = google_compute_instance.conversion_target[count.index].id
    timestamp   = timestamp()
  }
}

# Run convert2rhel conversion
resource "null_resource" "convert2rhel_conversion" {
  count = var.run_analysis_only ? 0 : var.instance_count

  depends_on = [null_resource.convert2rhel_analysis]

  connection {
    type        = "ssh"
    host        = google_compute_instance.conversion_target[count.index].network_interface[0].access_config[0].nat_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "10m"
  }

  # Run conversion
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '========================================='",
      "echo 'Convert2RHEL Setup - Conversion Phase'",
      "echo 'WARNING: This will convert the system to RHEL'",
      "echo '========================================='",
      "sudo /tmp/convert2rhel-setup \\",
      "  --org-id ${var.rh_org_id} \\",
      "  --activation-key ${var.rh_activation_key} \\",
      "  --assume-yes",
      "echo 'Conversion completed'",
    ]
  }

  # Save conversion results locally
  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute ssh ${var.ssh_user}@${google_compute_instance.conversion_target[count.index].name} \
        --zone=${var.zone} \
        --command="sudo cat /var/log/convert2rhel-setup-conversion.log" \
        > ./conversion-logs/gcp-conversion-instance-${count.index + 1}.log || true
    EOT
  }

  # Update instance labels
  provisioner "local-exec" {
    command = <<-EOT
      gcloud compute instances add-labels ${google_compute_instance.conversion_target[count.index].name} \
        --zone=${var.zone} \
        --labels=conversion-status=converted,conversion-date=$(date -u +%Y%m%d)
    EOT
  }

  triggers = {
    analysis_id = null_resource.convert2rhel_analysis[count.index].id
  }
}

# Reboot instances
resource "null_resource" "reboot_instances" {
  count = var.auto_reboot && !var.run_analysis_only ? var.instance_count : 0

  depends_on = [null_resource.convert2rhel_conversion]

  connection {
    type        = "ssh"
    host        = google_compute_instance.conversion_target[count.index].network_interface[0].access_config[0].nat_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Rebooting system to boot RHEL kernel...'",
      "sudo sync",
      "sudo reboot || true",
    ]
  }

  provisioner "local-exec" {
    command = "sleep 120"
  }

  triggers = {
    conversion_id = null_resource.convert2rhel_conversion[count.index].id
  }
}

# Post-conversion verification
resource "null_resource" "verify_conversion" {
  count = var.auto_reboot && !var.run_analysis_only ? var.instance_count : 0

  depends_on = [null_resource.reboot_instances]

  connection {
    type        = "ssh"
    host        = google_compute_instance.conversion_target[count.index].network_interface[0].access_config[0].nat_ip
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '========================================='",
      "echo 'Post-Conversion Verification'",
      "echo '========================================='",
      "cat /etc/redhat-release",
      "sudo subscription-manager status",
      "uname -r",
      "echo '========================================='",
    ]
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "GCP Instance ${count.index + 1} verification completed" >> ./conversion-logs/gcp-summary.txt
    EOT
  }

  triggers = {
    reboot_id = null_resource.reboot_instances[count.index].id
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "zone" {
  description = "GCP Zone"
  value       = var.zone
}

output "instance_names" {
  description = "Names of created instances"
  value       = google_compute_instance.conversion_target[*].name
}

output "instance_ids" {
  description = "IDs of created instances"
  value       = google_compute_instance.conversion_target[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of instances"
  value       = google_compute_instance.conversion_target[*].network_interface[0].access_config[0].nat_ip
}

output "instance_private_ips" {
  description = "Private IP addresses of instances"
  value       = google_compute_instance.conversion_target[*].network_interface[0].network_ip
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = [
    for instance in google_compute_instance.conversion_target :
    "gcloud compute ssh ${var.ssh_user}@${instance.name} --zone=${var.zone}"
  ]
}

output "console_urls" {
  description = "GCP Console URLs for instances"
  value = [
    for instance in google_compute_instance.conversion_target :
    "https://console.cloud.google.com/compute/instancesDetail/zones/${var.zone}/instances/${instance.name}?project=${var.project_id}"
  ]
}

output "conversion_status" {
  description = "Conversion status"
  value = var.run_analysis_only ? "Analysis completed. Review logs in ./conversion-logs/" : "Conversion completed. Instances may require reboot."
}

output "log_location" {
  description = "Local log file location"
  value       = "${path.module}/conversion-logs/"
}

output "next_steps" {
  description = "Next steps after conversion"
  value = var.run_analysis_only ? [
    "1. Review analysis logs in ./conversion-logs/",
    "2. Address any inhibitors or warnings",
    "3. Run conversion: terraform apply -var='run_analysis_only=false'",
  ] : [
    "1. Review conversion logs in ./conversion-logs/",
    "2. Manually reboot instances if auto_reboot=false:",
    "   gcloud compute instances reset INSTANCE_NAME --zone=${var.zone}",
    "3. Verify RHEL: gcloud compute ssh USER@INSTANCE --zone=${var.zone}",
    "4. Update packages: sudo yum update -y",
  ]
}

# ============================================================================
# Example gcp.tfvars
# ============================================================================
#
# Create a gcp.tfvars file with your values:
#
# project_id           = "my-gcp-project"
# region               = "us-central1"
# zone                 = "us-central1-a"
# rh_org_id           = "1234567"
# rh_activation_key   = "your-activation-key"
# instance_count      = 1
# machine_type        = "n1-standard-2"
# ssh_user            = "centos"
# ssh_public_key_path = "~/.ssh/id_rsa.pub"
# ssh_private_key_path = "~/.ssh/id_rsa"
# run_analysis_only   = true
# auto_reboot         = false
#