# Security Policy

## Supported Versions

We provide security updates for the following versions:

| Version | Supported          | Status      |
|:--------|:-------------------|:------------|
| 1.3.x   | ✅ Yes             | Current     |
| 1.2.x   | ✅ Yes             | Maintained  |
| 1.1.x   | ⚠️ Limited support | Upgrade recommended |
| 1.0.x   | ❌ No              | End of Life |

**Recommendation:** Always use the latest stable release (1.3.x) for the best security and features.

## Security Considerations

### Critical Warnings

⚠️ **This script performs system-level modifications with root privileges.** Please observe the following security practices:

#### 1. Credential Security

**Activation Keys:**

- Never commit activation keys to version control
- Use environment variables or secure vaults (Ansible Vault, HashiCorp Vault)
- Rotate keys periodically
- Use restricted activation keys with minimal entitlements when possible

**Organization IDs:**

- Organization IDs are not highly sensitive but should still be protected
- Avoid exposing them in public repositories or logs

**Best Practices:**

```bash
# ✅ Good: Use environment variables
export RH_ORG_ID="1234567"
export RH_ACTIVATION_KEY="your-key"
sudo -E ./convert2rhel-setup

# ✅ Good: Use Ansible Vault
ansible-vault create group_vars/all/vault.yml

# ❌ Bad: Hardcoding in scripts
./script.sh --activation-key "my-secret-key"  # This appears in shell history!

# ❌ Bad: Committing to git
git add credentials.txt  # Never do this!
```

#### 2. Script Verification

**Before running the script:**

```bash
# Download from official source
curl -fsSL -o convert2rhel-setup \
  https://raw.githubusercontent.com/khodaparastan/convert2rhel-automation/main/convert2rhel-setup

# Verify the script content
less convert2rhel-setup

# Check for suspicious content
grep -E "(eval|exec|base64|wget.*\|.*sh|curl.*\|.*sh)" convert2rhel-setup

# Verify the shebang
head -1 convert2rhel-setup
# Expected: #!/usr/bin/env bash

# Run ShellCheck
shellcheck convert2rhel-setup
```

**Checksum Verification:**

We provide SHA256 checksums for releases. Verify downloads:

```bash
# Download the script
curl -fsSL -o convert2rhel-setup \
  https://raw.githubusercontent.com/khodaparastan/convert2rhel-automation/v1.3.0/convert2rhel-setup

# Download checksum (when available)
curl -fsSL -o convert2rhel-setup.sha256 \
  https://raw.githubusercontent.com/khodaparastan/convert2rhel-automation/v1.3.0/convert2rhel-setup.sha256

# Verify
sha256sum -c convert2rhel-setup.sha256
```

#### 3. Execution Environment

**Network Security:**

```bash
# Ensure connections are over HTTPS only
# The script only connects to:
# - https://cdn-public.redhat.com
# - https://subscription.rhsm.redhat.com
# - https://security.access.redhat.com

# If using a proxy, ensure it's trusted
export https_proxy="https://trusted-proxy.example.com:8080"
```

**File Permissions:**

```bash
# The script creates files with secure permissions:
# - Config files: 600 (owner read/write only)
# - Temporary directories: 700 (owner access only)
# - Log files: 600 (owner read/write only)

# Verify after execution
ls -la /etc/convert2rhel.ini
# Expected: -rw------- (600)

ls -la /var/log/convert2rhel-setup.log
# Expected: -rw------- (600)
```

#### 4. System Access

**Root Privileges:**

This script **requires root access** to:

- Install packages
- Modify system configuration
- Replace system packages during conversion

**Mitigation:**

- Always review the script before running with root
- Test in non-production environments first
- Use analysis-only mode (`--analyze-only`) for initial testing
- Maintain backups before running conversion

**Audit Trail:**

```bash
# The script logs all actions:
tail -f /var/log/convert2rhel-setup.log

# Review actions taken:
grep -E "(INFO|SUCCESS|WARNING|ERROR)" /var/log/convert2rhel-setup.log
```

#### 5. Data Protection

**What gets logged:**

- Command-line arguments (activation key is masked)
- System information (OS version, disk space)
- Package installation progress
- Conversion steps and results

**What is NOT logged:**

- Full activation keys (only first 4 characters shown)
- User passwords
- SSH keys or certificates

**Log Security:**

```bash
# Logs contain sensitive information - secure them
chmod 600 /var/log/convert2rhel-setup*.log
chown root:root /var/log/convert2rhel-setup*.log

# Rotate logs regularly
logrotate /etc/logrotate.d/convert2rhel

# Archive and encrypt old logs
tar -czf conversion-logs-$(date +%Y%m%d).tar.gz /var/log/convert2rhel*.log
gpg -c conversion-logs-*.tar.gz
```

## Known Security Considerations

### 1. Package Repository Trust

**Risk:** The script downloads and installs packages from Red Hat repositories.

**Mitigation:**

- GPG keys are verified before package installation
- Repository files are validated before use
- Only official Red Hat CDN endpoints are used
- HTTPS is enforced for all downloads

### 2. Credential Exposure

**Risk:** Credentials in command-line arguments may appear in process listings or shell history.

**Mitigation:**

- Use environment variables instead of command-line arguments
- Activation keys are masked in log files (only 4 characters visible)
- Avoid running with verbose logging in production

**Example:**

```bash
# ⚠️ Less secure: Visible in process list
./convert2rhel-setup --activation-key "secret123"

# ✅ More secure: Environment variables
export RH_ACTIVATION_KEY="secret123"
./convert2rhel-setup
```

### 3. Temporary File Security

**Risk:** Sensitive data in temporary files could be exposed.

**Mitigation:**

- Temporary directories created with `umask 077` (700 permissions)
- Automatic cleanup on script exit
- Temporary files only readable by root

### 4. Network Interception

**Risk:** Credentials or data intercepted during network transmission.

**Mitigation:**

- All connections use HTTPS/TLS
- Certificate validation enforced by curl
- No credentials transmitted in URLs (POST body only)

### 5. Supply Chain Security

**Risk:** Compromised dependencies or scripts.

**Mitigation:**

- Minimal dependencies (standard Linux tools only)
- No third-party scripts or libraries
- All external downloads are from official Red Hat sources
- Repository and GPG key validation

## Reporting a Vulnerability

### Reporting Process

If you discover a security vulnerability, please follow this process:

1. **DO NOT** open a public GitHub issue for security vulnerabilities
2. **DO NOT** disclose the vulnerability publicly until it has been addressed

3. **Email the maintainer** with details:
   - Email: [Create a security advisory on GitHub](https://github.com/khodaparastan/convert2rhel-automation/security/advisories/new)
   - Subject: "SECURITY: [Brief description]"
   - Include:
     - Vulnerability description
     - Steps to reproduce
     - Potential impact
     - Suggested fix (if any)

4. **Expected Response Time:**
   - Initial acknowledgment: Within 48 hours
   - Status update: Within 7 days
   - Fix timeline: Depends on severity

### Severity Levels

| Level    | Description                                 | Response Time |
|:---------|:--------------------------------------------|:--------------|
| Critical | Remote code execution, credential exposure  | 24-48 hours   |
| High     | Privilege escalation, data exposure         | 3-7 days      |
| Medium   | Denial of service, information disclosure   | 1-2 weeks     |
| Low      | Minor issues with minimal impact            | 2-4 weeks     |

### What to Expect

1. **Acknowledgment:** We'll confirm receipt of your report
2. **Investigation:** We'll investigate and validate the vulnerability
3. **Fix Development:** We'll develop and test a fix
4. **Disclosure:** We'll coordinate disclosure timing with you
5. **Credit:** We'll credit you in the security advisory (if desired)

### Public Disclosure

- We follow **coordinated disclosure**
- Vulnerabilities will be disclosed after a fix is available
- Typically 90 days from report, or when fix is released
- Security advisories published on GitHub

## Security Best Practices for Users

### Before Running

1. **Verify Script Authenticity:**

   ```bash
   # Download from official repository only
   # Check the script content
   # Run ShellCheck for suspicious patterns
   ```

2. **Secure Credentials:**

   ```bash
   # Use environment variables
   # Never commit credentials
   # Rotate keys after use in shared environments
   ```

3. **Test in Safe Environment:**

   ```bash
   # Use VMs or containers
   # Take snapshots before conversion
   # Test with --analyze-only first
   ```

### During Execution

1. **Monitor Execution:**

   ```bash
   # Watch logs in real-time
   tail -f /var/log/convert2rhel-setup.log

   # Check for suspicious network activity
   netstat -tupn | grep convert2rhel
   ```

2. **Limit Access:**

   ```bash
   # Run in isolated network if possible
   # Restrict SSH access during conversion
   # Monitor system resource usage
   ```

### After Execution

1. **Review Logs:**

   ```bash
   # Check for warnings or errors
   grep -E "(WARNING|ERROR)" /var/log/convert2rhel-setup.log

   # Review all changes made
   cat /var/log/convert2rhel/rpm_va.log
   ```

2. **Secure Cleanup:**

   ```bash
   # Remove credentials from environment
   unset RH_ACTIVATION_KEY
   unset RH_ORG_ID

   # Clear shell history if needed
   history -c

   # Archive and secure logs
   tar -czf logs.tar.gz /var/log/convert2rhel*.log
   chmod 600 logs.tar.gz
   ```

3. **Verify System State:**

   ```bash
   # Check subscription status
   subscription-manager status

   # Verify no unexpected packages
   rpm -qa | grep -v redhat

   # Check for unexpected services
   systemctl list-units --type=service
   ```

## Compliance and Auditing

### Audit Trail

The script maintains comprehensive logs for compliance purposes:

```bash
# Main actions log
/var/log/convert2rhel-setup.log

# Analysis phase details
/var/log/convert2rhel-setup-analysis.log

# Conversion phase details
/var/log/convert2rhel-setup-conversion.log

# convert2rhel tool logs
/var/log/convert2rhel/convert2rhel.log

# RPM verification
/var/log/convert2rhel/rpm_va.log
```

### Retention Recommendations

- **Minimum:** 90 days
- **Recommended:** 1 year
- **Compliance:** Follow your organization's requirements

### Log Analysis

```bash
# Extract key events
grep "SYSTEM\|SUCCESS\|ERROR" /var/log/convert2rhel-setup.log

# Timeline of conversion
grep "$(date +%Y-%m-%d)" /var/log/convert2rhel-setup.log

# Package changes
rpm -qa --last | head -100
```

## Security Updates

### How Updates Are Distributed

1. **GitHub Releases:** New versions published with changelogs
2. **Security Advisories:** Published for critical vulnerabilities
3. **CHANGELOG.md:** Documents security-related changes

### Staying Updated

```bash
# Check current version
./convert2rhel-setup --help | grep version

# Subscribe to repository releases
# Watch: https://github.com/khodaparastan/convert2rhel-automation
```

### Automatic Update Check (Optional)

```bash
# Check for latest version
LATEST=$(curl -s https://api.github.com/repos/khodaparastan/convert2rhel-automation/releases/latest | grep tag_name | cut -d'"' -f4)
echo "Latest version: ${LATEST}"

# Compare with installed version
./convert2rhel-setup --help | grep -q "${LATEST}" || echo "Update available!"
```

## Additional Resources

- **Red Hat Security:** [access.redhat.com/security](https://access.redhat.com/security)
- **convert2rhel Security:** [access.redhat.com/documentation](https://access.redhat.com/documentation)
- **RHEL Security Guide:** [Red Hat Enterprise Linux Security Guide](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/9/html/security_hardening/)

## Contact

For security concerns:

- **GitHub Security Advisories:** [Create Advisory](https://github.com/khodaparastan/convert2rhel-automation/security/advisories/new)
- **General Issues:** [GitHub Issues](https://github.com/khodaparastan/convert2rhel-automation/issues) (non-security only)

---

**Last Updated:** 2025-10-01
**Version:** 1.3.0
