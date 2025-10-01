# Convert2RHEL Setup - Quick Reference Guide

**Version:** 1.3.0
**Last Updated:** 2025-10-01

Quick reference for the Convert2RHEL automated setup script. For full documentation, see [README.md](README.md).

---

## Table of Contents

- [Command Syntax](#command-syntax)
- [Common Workflows](#common-workflows)
- [Environment Variables](#environment-variables)
- [Log Locations](#log-locations)
- [Exit Codes](#exit-codes)
- [Troubleshooting Commands](#troubleshooting-commands)
- [Pre-Conversion Checklist](#pre-conversion-checklist)

---

## Command Syntax

### Basic Usage

```bash
./convert2rhel-setup [OPTIONS]
```

### Required Parameters

```bash
-o, --org-id <ID>          # Your Red Hat organization ID (numeric)
-k, --activation-key <KEY> # Your Red Hat activation key (alphanumeric)
```

**Get credentials:**

- Organization ID: [Red Hat Customer Portal](https://access.redhat.com/) → Account Settings
- Activation Key: [Console](https://console.redhat.com/insights/connector/activation-keys) → Create Key

### Optional Flags

| Flag                   | Description                              | Use Case                                      |
|:-----------------------|:-----------------------------------------|:----------------------------------------------|
| `-a, --analyze-only`   | Run analysis only, no conversion         | Test compatibility before converting          |
| `-s, --skip-analysis`  | Skip pre-conversion analysis             | ⚠️ Advanced: Use only after separate analysis |
| `-y, --assume-yes`     | Skip ALL prompts (fully unattended)      | Automation, CI/CD pipelines                   |
| `-v, --verbose`        | Show package manager output in real-time | Interactive troubleshooting                   |
| `--skip-base-packages` | Skip optional utility packages           | Minimal installations                         |
| `-h, --help`           | Display help message                     | Quick reference in terminal                   |

---

## Common Workflows

### 1. Analysis Only (⭐ Recommended First Step)

Test system compatibility without making changes:

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key \
  --analyze-only
```

**What happens:**

- ✅ Installs prerequisites
- ✅ Runs compatibility analysis
- ✅ Generates report
- ❌ Does NOT convert

**Review:** Check `/var/log/convert2rhel-setup-analysis.log`

---

### 2. Interactive Conversion (Safest)

Full conversion with confirmation prompts:

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key
```

**User will be prompted:**

1. Before running analysis
2. Before starting conversion
3. At convert2rhel's critical checkpoint
4. Before reboot

**Best for:** Production systems, cautious approach

---

### 3. Fully Unattended (Automation)

Complete automation with zero user interaction:

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key \
  --assume-yes
```

**What happens:**

- 🤖 No prompts at all
- 🤖 Passes `-y` to convert2rhel
- 🤖 Runs start to finish automatically
- ⚠️ Does NOT auto-reboot (manual reboot required)

**Best for:** CI/CD, Ansible, mass conversions

---

### 4. Unattended Analysis

Run analysis without prompts:

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key \
  --analyze-only \
  --assume-yes
```

**Best for:** Pre-flight checks in automation

---

### 5. Skip Analysis (⚠️ Advanced)

Skip pre-conversion checks (risky):

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key \
  --skip-analysis \
  --assume-yes
```

**⚠️ WARNING:**

- Bypasses safety checks
- May fail mid-conversion
- Only use after separate analysis

---

### 6. With Environment Variables

Set credentials once, use multiple times:

```bash
# Set credentials
export RH_ORG_ID="1234567"
export RH_ACTIVATION_KEY="my-activation-key"

# Run analysis (use -E to preserve env vars with sudo)
sudo -E ./convert2rhel-setup --analyze-only

# Review results, then convert
sudo -E ./convert2rhel-setup --assume-yes
```

---

### 7. Verbose Mode for Troubleshooting (New in v1.3.0)

See package installation output in real-time:

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key \
  --verbose \
  --analyze-only
```

**Best for:** Interactive debugging, seeing errors immediately

---

### 8. Minimal Installation (New in v1.3.0)

Skip optional utility packages (tmux, vim, wget, curl, sos):

```bash
sudo ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key \
  --skip-base-packages
```

**Best for:** Minimal environments, containers, compliance requirements

---

### 9. Custom Log Location

```bash
sudo LOG_FILE=/custom/path/conversion.log \
  ./convert2rhel-setup \
  --org-id 1234567 \
  --activation-key my-activation-key
```

**Generated logs:**

- `/custom/path/conversion.log` (main)
- `/custom/path/conversion-analysis.log`
- `/custom/path/conversion-conversion.log`

---

## Environment Variables

| Variable            | Purpose                        | Example                                 |
|:--------------------|:-------------------------------|:----------------------------------------|
| `RH_ORG_ID`         | Red Hat organization ID        | `export RH_ORG_ID="1234567"`            |
| `RH_ACTIVATION_KEY` | Red Hat activation key         | `export RH_ACTIVATION_KEY="mykey"`      |
| `LOG_FILE`          | Custom log file path           | `export LOG_FILE="/var/log/custom.log"` |
| `SKIP_BASE_PKGS`    | Skip base package installation | `export SKIP_BASE_PKGS=true`            |

**Usage with sudo:**

```bash
export RH_ORG_ID="1234567"
export RH_ACTIVATION_KEY="mykey"

# Option 1: Use -E flag
sudo -E ./convert2rhel-setup

# Option 2: Inline
sudo RH_ORG_ID="1234567" RH_ACTIVATION_KEY="mykey" \
  ./convert2rhel-setup
```

---

## Log Locations

### Default Logs

| Log File                                     | Purpose                          | When Created      |
|:---------------------------------------------|:---------------------------------|:------------------|
| `/var/log/convert2rhel-setup.log`            | Main script log                  | Always            |
| `/var/log/convert2rhel-setup-analysis.log`   | Analysis phase output            | During analysis   |
| `/var/log/convert2rhel-setup-conversion.log` | Conversion phase output          | During conversion |
| `/var/log/convert2rhel/convert2rhel.log`     | Convert2rhel tool log (detailed) | During conversion |
| `/var/log/convert2rhel/rpm_va.log`           | Modified package files           | During conversion |

### Viewing Logs

```bash
# View full log
sudo less /var/log/convert2rhel-setup.log

# View last 50 lines
sudo tail -n 50 /var/log/convert2rhel-setup.log

# Follow in real-time
sudo tail -f /var/log/convert2rhel-setup-conversion.log

# Search for errors
sudo grep -i error /var/log/convert2rhel-setup.log

# Search for warnings
sudo grep -i warning /var/log/convert2rhel-setup.log

# Get summary
sudo grep -E "(ERROR|WARNING|FAILED)" /var/log/convert2rhel-setup.log
```

---

## Exit Codes

| Exit Code | Meaning              | Description                                               |
|:----------|:---------------------|:----------------------------------------------------------|
| **0**     | Success              | All operations completed successfully                     |
| **1**     | General Error        | Unspecified error occurred                                |
| **2**     | Invalid Arguments    | Missing or invalid command-line parameters                |
| **3**     | Prerequisites Failed | Pre-flight checks failed (connectivity, disk space, etc.) |
| **4**     | Analysis Failed      | Pre-conversion analysis found blocking issues             |
| **5**     | Conversion Failed    | Conversion process failed                                 |
| **130**   | Interrupted          | User pressed Ctrl+C                                       |
| **143**   | Terminated           | Process killed by signal                                  |

### Using Exit Codes in Scripts

```bash
#!/bin/bash

./convert2rhel-setup -o 123456 -k mykey --analyze-only

case $? in
  0)
    echo "✅ Analysis passed - safe to convert"
    ./convert2rhel-setup -o 123456 -k mykey -y
    ;;
  4)
    echo "❌ Analysis found issues - review logs"
    exit 1
    ;;
  *)
    echo "⚠️ Unexpected error occurred"
    exit 1
    ;;
esac
```

---

## Troubleshooting Commands

### Check System State

```bash
# Verify OS
cat /etc/redhat-release
cat /etc/os-release

# Check subscription
sudo subscription-manager status
sudo subscription-manager list --consumed

# Verify repositories
sudo yum repolist
sudo dnf repolist  # RHEL 8/9

# Check disk space
df -h /

# Check memory
free -h
```

### Test Connectivity

```bash
# Test Red Hat endpoints (script checks these automatically)
curl -I https://redhat.com
curl -I https://cdn-public.redhat.com
curl -I https://subscription.rhsm.redhat.com

# Test DNS
nslookup cdn-public.redhat.com

# Check proxy settings
echo $http_proxy
echo $https_proxy
```

### View Installed Packages

```bash
# Count Red Hat packages
rpm -qa | grep -i redhat | wc -l

# Count old vendor packages
rpm -qa | grep -i centos | wc -l
rpm -qa | grep -i oracle | wc -l

# List extras (non-RHEL packages)
sudo yum list extras --disablerepo="*" --enablerepo=rhel-*
```

### Verify Conversion Success

```bash
# Check OS identification
cat /etc/redhat-release
# Expected: Red Hat Enterprise Linux release X.Y

# Verify subscription
sudo subscription-manager identity

# Check kernel
uname -r
# Expected: Red Hat kernel

# Verify Insights
sudo insights-client --status
```

### Clean Up After Conversion

```bash
# Remove leftover vendor packages
sudo yum remove $(yum list extras --disablerepo="*" --enablerepo=rhel-* -q)

# Update to latest
sudo yum update -y

# Clean cache
sudo yum clean all
```

---

## Pre-Conversion Checklist

Essential steps before converting any system:

### Planning

- [ ] Maintenance window scheduled (4-6 hours minimum)
- [ ] Stakeholders notified
- [ ] Rollback plan documented
- [ ] Emergency contacts identified

### Backups

- [ ] Full system backup completed
- [ ] Backup verified and restorable
- [ ] Database backups created
- [ ] Configuration files backed up

### Prerequisites

- [ ] Valid Red Hat subscription available
- [ ] Organization ID obtained
- [ ] Activation key created
- [ ] Network connectivity to Red Hat services verified
- [ ] Minimum 5 GB free disk space confirmed
- [ ] Root/sudo access available

### Testing

- [ ] Script tested in dev/staging environment
- [ ] Analysis completed successfully (`--analyze-only`)
- [ ] All inhibitors resolved
- [ ] All warnings reviewed and accepted
- [ ] Application compatibility verified

### System Preparation

- [ ] All packages updated to latest supported version
- [ ] Custom kernel modules documented/removed
- [ ] UEFI Secure Boot disabled (if applicable)
- [ ] Third-party repositories disabled
- [ ] Configuration management temporarily disabled
- [ ] Services status documented

### Final Checks

- [ ] Monitoring alerts adjusted
- [ ] On-call team notified and ready
- [ ] Post-conversion testing plan prepared
- [ ] Reboot window confirmed

---

## Ansible Playbook Example

```yaml
---
- name: Convert systems to RHEL
  hosts: centos_servers
  become: true
  vars:
    rh_org_id: "1234567"
    rh_activation_key: "{{ vault_activation_key }}"  # Use Ansible Vault
    script_path: "/tmp/convert2rhel-setup"

  tasks:
    - name: Copy conversion script
      copy:
        src: convert2rhel-setup
        dest: "{{ script_path }}"
        mode: '0755'

    - name: Run pre-conversion analysis
      command: >
        {{ script_path }}
        --org-id {{ rh_org_id }}
        --activation-key {{ rh_activation_key }}
        --analyze-only
        --assume-yes
      register: analysis
      failed_when: analysis.rc != 0

    - name: Display analysis results
      debug:
        var: analysis.stdout_lines

    - name: Pause for review
      pause:
        prompt: "Review analysis results. Press Enter to continue or Ctrl+C to abort"
      when: analysis.rc == 0

    - name: Run conversion
      command: >
        {{ script_path }}
        --org-id {{ rh_org_id }}
        --activation-key {{ rh_activation_key }}
        --assume-yes
      register: conversion
      when: analysis.rc == 0

    - name: Display conversion results
      debug:
        var: conversion.stdout_lines

    - name: Reboot system
      reboot:
        reboot_timeout: 600
        msg: "Rebooting after RHEL conversion"
      when: conversion.rc == 0

    - name: Wait for system to come back
      wait_for_connection:
        delay: 30
        timeout: 300

    - name: Verify RHEL conversion
      shell: |
        cat /etc/redhat-release
        subscription-manager status
      register: verify

    - name: Show verification
      debug:
        var: verify.stdout_lines
```

---

## Terraform Example

```hcl
resource "null_resource" "convert_to_rhel" {
  count = length(var.server_ips)

  connection {
    type        = "ssh"
    host        = var.server_ips[count.index]
    user        = "root"
    private_key = file(var.ssh_private_key_path)
  }

  # Copy script
  provisioner "file" {
    source      = "convert2rhel-setup"
    destination = "/tmp/convert2rhel-setup"
  }

  # Run analysis
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/convert2rhel-setup",
      "/tmp/convert2rhel-setup --org-id ${var.rh_org_id} --activation-key ${var.rh_activation_key} --analyze-only --assume-yes"
    ]
  }

  # Run conversion (if analysis passed)
  provisioner "remote-exec" {
    inline = [
      "/tmp/convert2rhel-setup --org-id ${var.rh_org_id} --activation-key ${var.rh_activation_key} --assume-yes",
      "reboot"
    ]
  }
}
```

---

## Common Error Solutions

### Error: "This script must be run as root"

```bash
sudo ./convert2rhel-setup -o XXX -k YYY
```

### Error: "No internet connectivity detected"

```bash
# Test connectivity
curl -I https://cdn.redhat.com

# Check firewall
sudo firewall-cmd --list-all

# If behind proxy
export http_proxy="http://proxy.example.com:8080"
export https_proxy="http://proxy.example.com:8080"
sudo -E ./convert2rhel-setup -o XXX -k YYY
```

### Error: "Insufficient disk space"

```bash
# Check space
df -h /

# Clean up
sudo yum clean all
sudo package-cleanup --oldkernels --count=2  # RHEL 7
```

### Error: "Analysis found inhibitors"

```bash
# Review analysis log
sudo cat /var/log/convert2rhel-setup-analysis.log

# Common fixes
sudo yum update -y  # Update all packages
sudo yum-config-manager --disable epel  # Disable third-party repos
```

---

## Support Resources

| Resource                        | URL                                                             |
|:--------------------------------|:----------------------------------------------------------------|
| **Official Documentation**      | <https://access.redhat.com/documentation/>                      |
| **Red Hat Support**             | <https://access.redhat.com/support>                             |
| **Activation Keys**             | <https://console.redhat.com/insights/connector/activation-keys> |
| **Supported Conversions**       | <https://access.redhat.com/articles/2360841>                    |
| **Convert2RHEL Support Policy** | <https://access.redhat.com/support/policy/convert2rhel-support> |

---

## Version Info

**Script Version:** 1.3.0
**Last Updated:** 2025-10-01
**Maintained By:** Khodaparastan

For full documentation and detailed guides, see [README.md](README.md).

---

## Quick Command Summary

```bash
# Get help
./convert2rhel-setup --help

# Analysis only
sudo ./convert2rhel-setup -o ORG_ID -k KEY -a

# Interactive conversion
sudo ./convert2rhel-setup -o ORG_ID -k KEY

# Fully automated
sudo ./convert2rhel-setup -o ORG_ID -k KEY -y

# Verbose mode (troubleshooting)
sudo ./convert2rhel-setup -o ORG_ID -k KEY -v -a

# Minimal installation (skip optional packages)
sudo ./convert2rhel-setup -o ORG_ID -k KEY --skip-base-packages

# Check logs
sudo tail -f /var/log/convert2rhel-setup.log

# Verify conversion
cat /etc/redhat-release && sudo subscription-manager status
```

---

**Need more details?** See the full [README.md](README.md) documentation.
