#
# Convert2RHEL Automation - Microsoft Azure Example
#
# This Terraform configuration demonstrates how to use convert2rhel-automation
# to convert Azure VMs running CentOS to RHEL.
#
# Requirements:
#   - Terraform 1.0+
#   - Azure CLI configured (az login)
#   - Azure subscription with appropriate permissions
#
# Usage:
#   terraform init
#   terraform plan
#   terraform apply -var-file="azure.tfvars"
#

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Azure location for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group name (will be created if doesn't exist)"
  type        = string
  default     = "rg-convert2rhel"
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
  description = "Number of VMs to convert"
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s" # 2 vCPUs, 4 GB memory
}

variable "admin_username" {
  description = "Admin username for VMs"
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
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_5" # CentOS 8.5
    version   = "latest"
  }
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
# Provider Configuration
# ============================================================================

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ============================================================================
# Random Suffix
# ============================================================================

resource "random_id" "suffix" {
  byte_length = 4
}

# ============================================================================
# Resource Group
# ============================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# ============================================================================
# Networking
# ============================================================================

resource "azurerm_virtual_network" "main" {
  name                = "vnet-convert2rhel-${random_id.suffix.hex}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = "subnet-convert2rhel"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "main" {
  name                = "nsg-convert2rhel-${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # Restrict this in production!
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# ============================================================================
# Public IPs
# ============================================================================

resource "azurerm_public_ip" "main" {
  count = var.instance_count

  name                = "pip-convert2rhel-${count.index + 1}-${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name = "centos-to-rhel-${count.index + 1}"
    }
  )
}

# ============================================================================
# Network Interfaces
# ============================================================================

resource "azurerm_network_interface" "main" {
  count = var.instance_count

  name                = "nic-convert2rhel-${count.index + 1}-${random_id.suffix.hex}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main[count.index].id
  }

  tags = var.tags
}

resource "azurerm_network_interface_security_group_association" "main" {
  count = var.instance_count

  network_interface_id      = azurerm_network_interface.main[count.index].id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ============================================================================
# Virtual Machines
# ============================================================================

resource "azurerm_linux_virtual_machine" "conversion_target" {
  count = var.instance_count

  name                = "vm-centos-to-rhel-${count.index + 1}-${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.main[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    name                 = "osdisk-centos-${count.index + 1}-${random_id.suffix.hex}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = var.centos_image.publisher
    offer     = var.centos_image.offer
    sku       = var.centos_image.sku
    version   = var.centos_image.version
  }

  disable_password_authentication = true

  tags = merge(
    var.tags,
    {
      ConversionStatus = "Pending"
      Name             = "centos-to-rhel-${count.index + 1}"
    }
  )
}

# Wait for VMs to be ready
resource "null_resource" "wait_for_vms" {
  count = var.instance_count

  depends_on = [azurerm_linux_virtual_machine.conversion_target]

  provisioner "local-exec" {
    command = "sleep 90"
  }
}

# ============================================================================
# Conversion Automation
# ============================================================================

# Run convert2rhel analysis
resource "null_resource" "convert2rhel_analysis" {
  count = var.instance_count

  depends_on = [null_resource.wait_for_vms]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.main[count.index].ip_address
    user        = var.admin_username
    private_key = file(var.ssh_private_key_path)
    timeout     = "5m"
  }

  # Download and setup script
  provisioner "remote-exec" {
    inline = [
      "set -e",
      "echo '========================================='",
      "echo 'Convert2RHEL Setup - Analysis Phase'",
      "echo 'VM: ${azurerm_linux_virtual_machine.conversion_target[count.index].name}'",
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
          ${var.admin_username}@${azurerm_public_ip.main[count.index].ip_address} \
          "sudo cat /var/log/convert2rhel-setup-analysis.log" \
          > ./conversion-logs/azure-analysis-instance-${count.index + 1}.log || true
    EOT
  }

  triggers = {
    vm_id     = azurerm_linux_virtual_machine.conversion_target[count.index].id
    timestamp = timestamp()
  }
}

# Run convert2rhel conversion
resource "null_resource" "convert2rhel_conversion" {
  count = var.run_analysis_only ? 0 : var.instance_count

  depends_on = [null_resource.convert2rhel_analysis]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.main[count.index].ip_address
    user        = var.admin_username
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
          ${var.admin_username}@${azurerm_public_ip.main[count.index].ip_address} \
          "sudo cat /var/log/convert2rhel-setup-conversion.log" \
          > ./conversion-logs/azure-conversion-instance-${count.index + 1}.log || true
    EOT
  }

  # Update VM tags
  provisioner "local-exec" {
    command = <<-EOT
      az vm update \
        --resource-group ${azurerm_resource_group.main.name} \
        --name ${azurerm_linux_virtual_machine.conversion_target[count.index].name} \
        --set "tags.ConversionStatus=Converted" "tags.ConversionDate=$(date -u +%Y-%m-%d)"
    EOT
  }

  triggers = {
    analysis_id = null_resource.convert2rhel_analysis[count.index].id
  }
}

# Reboot VMs
resource "null_resource" "reboot_vms" {
  count = var.auto_reboot && !var.run_analysis_only ? var.instance_count : 0

  depends_on = [null_resource.convert2rhel_conversion]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.main[count.index].ip_address
    user        = var.admin_username
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

  depends_on = [null_resource.reboot_vms]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.main[count.index].ip_address
    user        = var.admin_username
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
      echo "Azure VM ${count.index + 1} verification completed" >> ./conversion-logs/azure-summary.txt
    EOT
  }

  triggers = {
    reboot_id = null_resource.reboot_vms[count.index].id
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "subscription_id" {
  description = "Azure Subscription ID"
  value       = var.subscription_id
}

output "resource_group_name" {
  description = "Resource Group Name"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure Location"
  value       = var.location
}

output "vm_names" {
  description = "Names of created VMs"
  value       = azurerm_linux_virtual_machine.conversion_target[*].name
}

output "vm_ids" {
  description = "IDs of created VMs"
  value       = azurerm_linux_virtual_machine.conversion_target[*].id
}

output "public_ips" {
  description = "Public IP addresses of VMs"
  value       = azurerm_public_ip.main[*].ip_address
}

output "private_ips" {
  description = "Private IP addresses of VMs"
  value       = azurerm_network_interface.main[*].private_ip_address
}

output "ssh_commands" {
  description = "SSH commands to connect to VMs"
  value = [
    for i in range(var.instance_count) :
    "ssh -i ${var.ssh_private_key_path} ${var.admin_username}@${azurerm_public_ip.main[i].ip_address}"
  ]
}

output "portal_urls" {
  description = "Azure Portal URLs for VMs"
  value = [
    for vm in azurerm_linux_virtual_machine.conversion_target :
    "https://portal.azure.com/#@/resource${vm.id}/overview"
  ]
}

output "conversion_status" {
  description = "Conversion status"
  value       = var.run_analysis_only ? "Analysis completed. Review logs in ./conversion-logs/" : "Conversion completed. VMs may require reboot."
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
    "2. Manually reboot VMs if auto_reboot=false:",
    "   az vm restart --resource-group ${azurerm_resource_group.main.name} --name VM_NAME",
    "3. Verify RHEL: ssh to VMs and run 'cat /etc/redhat-release'",
    "4. Update packages: sudo yum update -y",
  ]
}

# ============================================================================
# Example azure.tfvars
# ============================================================================
#
# Create an azure.tfvars file with your values:
#
# subscription_id      = "00000000-0000-0000-0000-000000000000"
# location             = "eastus"
# resource_group_name  = "rg-convert2rhel"
# rh_org_id           = "1234567"
# rh_activation_key   = "your-activation-key"
# instance_count      = 1
# vm_size             = "Standard_B2s"
# admin_username      = "centos"
# ssh_public_key_path = "~/.ssh/id_rsa.pub"
# ssh_private_key_path = "~/.ssh/id_rsa"
# run_analysis_only   = true
# auto_reboot         = false
#