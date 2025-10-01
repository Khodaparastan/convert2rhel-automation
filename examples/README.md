# Convert2RHEL Automation - Examples

This directory contains production-ready examples for using convert2rhel-automation across major cloud platforms and automation tools.

## Contents

- [`ansible-playbook.yml`](ansible-playbook.yml) - Ansible playbook for automated conversions
- [`terraform-aws.tf`](terraform-aws.tf) - Terraform for AWS EC2 instances
- [`terraform-gcp.tf`](terraform-gcp.tf) - Terraform for Google Cloud Platform
- [`terraform-azure.tf`](terraform-azure.tf) - Terraform for Microsoft Azure

---

## Terraform - Google Cloud Platform (GCP)

### Prerequisites

```bash
# Install Terraform
brew install terraform  # macOS

# Install Google Cloud SDK
brew install --cask google-cloud-sdk  # macOS
# Or download from: https://cloud.google.com/sdk/docs/install

# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
```

### Setup

1. **Create `gcp.tfvars`**:

   ```hcl
   project_id           = "my-gcp-project"
   region               = "us-central1"
   zone                 = "us-central1-a"
   rh_org_id           = "1234567"
   rh_activation_key   = "your-activation-key"
   instance_count      = 1
   machine_type        = "n1-standard-2"
   ssh_user            = "centos"
   ssh_public_key_path = "~/.ssh/id_rsa.pub"
   ssh_private_key_path = "~/.ssh/id_rsa"
   ```

2. **Initialize Terraform**:

```bash
terraform init
```

### Usage

```bash
# Analysis only
terraform apply -var-file="gcp.tfvars" -var='run_analysis_only=true'

# Review logs
cat conversion-logs/gcp-analysis-instance-1.log

# Run conversion
terraform apply -var-file="gcp.tfvars" -var='run_analysis_only=false'

# With automatic reboot
terraform apply -var-file="gcp.tfvars" \
  -var='run_analysis_only=false' \
  -var='auto_reboot=true'

# Destroy resources
terraform destroy -var-file="gcp.tfvars"
```

### GCP-Specific Commands

```bash
# List instances
gcloud compute instances list

# SSH to instance
gcloud compute ssh centos@INSTANCE_NAME --zone=us-central1-a

# Reboot instance
gcloud compute instances reset INSTANCE_NAME --zone=us-central1-a

# View console
gcloud compute instances get-serial-port-output INSTANCE_NAME --zone=us-central1-a
```

---

## Terraform - Microsoft Azure

### Azure Prerequisites

```bash
# Install Terraform
brew install terraform  # macOS

# Install Azure CLI
brew install azure-cli  # macOS
# Or download from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# Authenticate
az login

# List subscriptions
az account list --output table

# Set subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Azure Setup

1. **Create `azure.tfvars`**:

   ```hcl
   subscription_id      = "00000000-0000-0000-0000-000000000000"
   location             = "eastus"
   resource_group_name  = "rg-convert2rhel"
   rh_org_id           = "1234567"
   rh_activation_key   = "your-activation-key"
   instance_count      = 1
   vm_size             = "Standard_B2s"
   admin_username      = "centos"
   ssh_public_key_path = "~/.ssh/id_rsa.pub"
   ssh_private_key_path = "~/.ssh/id_rsa"
   ```

2. **Initialize Terraform**:

```bash
terraform init
```

### Azure Usage

```bash
# Analysis only
terraform apply -var-file="azure.tfvars" -var='run_analysis_only=true'

# Review logs
cat conversion-logs/azure-analysis-instance-1.log

# Run conversion
terraform apply -var-file="azure.tfvars" -var='run_analysis_only=false'

# With automatic reboot
terraform apply -var-file="azure.tfvars" \
  -var='run_analysis_only=false' \
  -var='auto_reboot=true'

# Destroy resources
terraform destroy -var-file="azure.tfvars"
```

### Azure-Specific Commands

```bash
# List VMs
az vm list --output table

# Show VM details
az vm show --resource-group rg-convert2rhel --name VM_NAME

# SSH to VM
ssh -i ~/.ssh/id_rsa centos@PUBLIC_IP

# Reboot VM
az vm restart --resource-group rg-convert2rhel --name VM_NAME

# Get VM status
az vm get-instance-view --resource-group rg-convert2rhel --name VM_NAME
```

---

## Cloud Platform Comparison

| Feature            | AWS                        | GCP                       | Azure                           |
|:-------------------|:---------------------------|:--------------------------|:--------------------------------|
| **Authentication** | IAM credentials            | gcloud auth               | az login                        |
| **VM Resource**    | `aws_instance`             | `google_compute_instance` | `azurerm_linux_virtual_machine` |
| **SSH User**       | `ec2-user` / `centos`      | `centos`                  | Configurable (`admin_username`) |
| **Networking**     | VPC/Subnet                 | VPC/Subnet                | VNet/Subnet                     |
| **CLI SSH**        | `aws ec2-instance-connect` | `gcloud compute ssh`      | Standard `ssh`                  |
| **Console**        | AWS Console                | GCP Console               | Azure Portal                    |
| **Default Region** | `us-east-1`                | `us-central1`             | `eastus`                        |

---

## Multi-Cloud Workflow

### 1. Analysis Across All Clouds

```bash
# AWS
terraform apply -var-file="aws.tfvars" -var='run_analysis_only=true'

# GCP
terraform apply -var-file="gcp.tfvars" -var='run_analysis_only=true'

# Azure
terraform apply -var-file="azure.tfvars" -var='run_analysis_only=true'
```

### 2. Review All Results

```bash
# View all analysis logs
ls -lh conversion-logs/*-analysis-*.log

# Search for errors across all logs
grep -i error conversion-logs/*-analysis-*.log
```

### 3. Convert All Clouds

```bash
# Parallel execution (use with caution)
terraform apply -var-file="aws.tfvars" &
terraform apply -var-file="gcp.tfvars" &
terraform apply -var-file="azure.tfvars" &
wait

echo "All conversions complete"
```

---

## Cost Considerations

### Estimated Hourly Costs (as of 2025)

| Cloud     | Instance Type | vCPUs | Memory | Hourly Cost |
|:----------|:--------------|:------|:-------|:------------|
| **AWS**   | t3.medium     | 2     | 4 GB   | ~$0.042/hr  |
| **GCP**   | n1-standard-2 | 2     | 7.5 GB | ~$0.095/hr  |
| **Azure** | Standard_B2s  | 2     | 4 GB   | ~$0.041/hr  |

**Note:** Costs vary by region and change over time. Check current pricing:

- AWS: <https://aws.amazon.com/ec2/pricing/>
- GCP: <https://cloud.google.com/compute/vm-instance-pricing>
- Azure: <https://azure.microsoft.com/en-us/pricing/calculator/>

### Cost Optimization Tips

1. **Use analysis-only mode first** (free, no conversion)
2. **Destroy resources after conversion**: `terraform destroy`
3. **Use smaller instances for testing**
4. **Choose cost-effective regions**
5. **Set up billing alerts**

---

## Security Best Practices

### All Clouds

```bash
# Store credentials securely
export TF_VAR_rh_org_id="1234567"
export TF_VAR_rh_activation_key="your-key"

# Use .gitignore
echo "*.tfvars" >> .gitignore
echo "*.pem" >> .gitignore
echo "*.key" >> .gitignore

# Restrict SSH access (update in .tf files)
# Change from: source_address_prefix = "*"
# To:          source_address_prefix = "YOUR_IP/32"
```

### Cloud-Specific Secrets Management

```bash
# AWS - Use AWS Secrets Manager
aws secretsmanager create-secret \
  --name rhel-conversion-creds \
  --secret-string '{"org_id":"123","key":"abc"}'

# GCP - Use Secret Manager
echo -n "your-activation-key" | \
  gcloud secrets create rh-activation-key --data-file=-

# Azure - Use Key Vault
az keyvault secret set \
  --vault-name myKeyVault \
  --name rh-activation-key \
  --value "your-activation-key"
```

---

## Troubleshooting

### Common Issues

#### GCP: "Permission denied" error

```bash
# Check project
gcloud config get-value project

# Enable required APIs
gcloud services enable compute.googleapis.com

# Check IAM roles
gcloud projects get-iam-policy PROJECT_ID
```

#### Azure: "Subscription not found"

```bash
# List subscriptions
az account list --output table

# Set correct subscription
az account set --subscription "SUBSCRIPTION_ID"

# Verify
az account show
```

#### All Clouds: SSH timeout

```bash
# Check security groups/firewall rules allow SSH (port 22)
# Verify public IP is reachable:
ping PUBLIC_IP

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
```

---

## Support

For cloud-specific issues:

- **AWS**: <https://aws.amazon.com/support/>
- **GCP**: <https://cloud.google.com/support/>
- **Azure**: <https://azure.microsoft.com/en-us/support/>

For convert2rhel issues:

- Red Hat Support: <https://access.redhat.com/support>
- Documentation: [Main README](../README.md)
