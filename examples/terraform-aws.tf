# Convert2RHEL Automation - Terraform Example
#
# This Terraform configuration demonstrates how to use convert2rhel-automation
# to convert existing EC2 instances or create new ones and convert them.
#
# Requirements:
#   - Terraform 1.0+
#   - AWS credentials configured
#   - SSH key pair for instance access
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply
#
# Variables can be set via:
#   - terraform.tfvars file
#   - Environment variables (TF_VAR_variable_name)
#   - Command line (-var="variable=value")
#

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
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

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
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

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "ssh_key_name" {
  description = "AWS SSH key pair name"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "centos_ami" {
  description = "CentOS AMI ID (will be converted to RHEL)"
  type        = string
  # CentOS 8 AMI (example - use appropriate AMI for your region)
  default = "ami-0e148f9e86049e155"
}

variable "subnet_id" {
  description = "Subnet ID for instances"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for instances"
  type        = string
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "RHEL-Conversion"
    ManagedBy   = "Terraform"
    Environment = "Migration"
  }
}

# ============================================================================
# Data Sources
# ============================================================================

data "aws_ami" "centos" {
  most_recent = true
  owners      = ["679593333241"] # CentOS official

  filter {
    name   = "name"
    values = ["CentOS-8*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================================
# Resources
# ============================================================================

# EC2 Instances to be converted
resource "aws_instance" "conversion_target" {
  count = var.instance_count

  ami                    = var.centos_ami != "" ? var.centos_ami : data.aws_ami.centos.id
  instance_type          = var.instance_type
  key_name               = var.ssh_key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  root_block_device {
    volume_size = 20 # GB
    volume_type = "gp3"
    encrypted   = true
  }

  tags = merge(
    var.tags,
    {
      Name             = "centos-to-rhel-${count.index + 1}"
      ConversionStatus = "Pending"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Wait for instances to be ready
resource "null_resource" "wait_for_instances" {
  count = var.instance_count

  depends_on = [aws_instance.conversion_target]

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

  depends_on = [null_resource.wait_for_instances]

  connection {
    type        = "ssh"
    host        = aws_instance.conversion_target[count.index].public_ip
    user        = "centos" # Adjust based on AMI
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  # Download and setup script
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '========================================='",
      "echo 'Convert2RHEL Setup - Analysis Phase'",
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
      ssh -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          centos@${aws_instance.conversion_target[count.index].public_ip} \
          "sudo cat /var/log/convert2rhel-setup-analysis.log" \
          > ./conversion-logs/analysis-instance-${count.index + 1}.log || true
    EOT
  }

  triggers = {
    instance_id = aws_instance.conversion_target[count.index].id
    timestamp   = timestamp()
  }
}

# Run convert2rhel conversion (only if not analysis-only mode)
resource "null_resource" "convert2rhel_conversion" {
  count = var.run_analysis_only ? 0 : var.instance_count

  depends_on = [null_resource.convert2rhel_analysis]

  connection {
    type        = "ssh"
    host        = aws_instance.conversion_target[count.index].public_ip
    user        = "centos"
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
      ssh -i ${var.ssh_private_key_path} \
          -o StrictHostKeyChecking=no \
          centos@${aws_instance.conversion_target[count.index].public_ip} \
          "sudo cat /var/log/convert2rhel-setup-conversion.log" \
          > ./conversion-logs/conversion-instance-${count.index + 1}.log || true
    EOT
  }

  # Tag instance as converted
  provisioner "local-exec" {
    command = <<-EOT
      aws ec2 create-tags \
        --region ${var.aws_region} \
        --resources ${aws_instance.conversion_target[count.index].id} \
        --tags Key=ConversionStatus,Value=Converted Key=ConversionDate,Value=$(date -u +%Y-%m-%d)
    EOT
  }

  triggers = {
    analysis_id = null_resource.convert2rhel_analysis[count.index].id
  }
}

# Reboot instances (optional)
resource "null_resource" "reboot_instances" {
  count = var.auto_reboot && !var.run_analysis_only ? var.instance_count : 0

  depends_on = [null_resource.convert2rhel_conversion]

  connection {
    type        = "ssh"
    host        = aws_instance.conversion_target[count.index].public_ip
    user        = "centos"
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

  # Wait for reboot
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
    host        = aws_instance.conversion_target[count.index].public_ip
    user        = "ec2-user" # RHEL uses ec2-user
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
      echo "Instance ${count.index + 1} verification completed" >> ./conversion-logs/summary.txt
    EOT
  }

  triggers = {
    reboot_id = null_resource.reboot_instances[count.index].id
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "instance_ids" {
  description = "IDs of created instances"
  value       = aws_instance.conversion_target[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of instances"
  value       = aws_instance.conversion_target[*].public_ip
}

output "instance_private_ips" {
  description = "Private IP addresses of instances"
  value       = aws_instance.conversion_target[*].private_ip
}

output "ssh_commands" {
  description = "SSH commands to connect to instances"
  value = [
    for i in range(var.instance_count) :
    "ssh -i ${var.ssh_private_key_path} centos@${aws_instance.conversion_target[i].public_ip}"
  ]
}

output "conversion_status" {
  description = "Conversion status"
  value       = var.run_analysis_only ? "Analysis completed. Review logs in ./conversion-logs/" : "Conversion completed. Instances may require reboot."
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
    "2. Manually reboot instances if auto_reboot=false",
    "3. Verify RHEL: ssh to instances and run 'cat /etc/redhat-release'",
    "4. Update to latest packages: 'sudo yum update -y'",
  ]
}

# ============================================================================
# Example terraform.tfvars
# ============================================================================
#
# Create a terraform.tfvars file with your values:
#
# aws_region           = "us-east-1"
# rh_org_id           = "1234567"
# rh_activation_key   = "your-activation-key"
# instance_count      = 2
# ssh_key_name        = "my-key-pair"
# ssh_private_key_path = "~/.ssh/my-key.pem"
# subnet_id           = "subnet-xxxxx"
# security_group_id   = "sg-xxxxx"
# run_analysis_only   = true
# auto_reboot         = false
#