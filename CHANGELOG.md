# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-10-01

### Added

- Verbose mode (`-v, --verbose`) flag for real-time package manager output during interactive sessions
- `--skip-base-packages` flag to skip installation of optional utility packages (tmux, vim, wget, curl, sos)
- `SKIP_BASE_PKGS` environment variable support for controlling base package installation
- Enhanced error handling with better exit codes and error messages
- Improved color-coded terminal output with fallback for non-color terminals
- Architecture detection for ARM64/aarch64 support in addition to x86_64
- Comprehensive inline documentation and help text
- Extended documentation with verbose mode examples
- Production-ready Terraform examples for AWS, GCP, and Azure
- Production-ready Ansible playbook with vault integration

### Changed

- Improved package installation with individual package handling and better error reporting
- Enhanced log file creation with secure permissions (600)
- Better handling of failed base package installations (non-fatal)
- Updated documentation to reflect new verbose and skip-base-packages options
- Improved connectivity checks with better error messages
- Enhanced script header with more comprehensive usage information

### Fixed

- Package manager output now properly redirected in both verbose and quiet modes
- Color support detection made more robust with multiple fallback mechanisms
- Temp directory creation with proper security (umask 077)
- GPG key and repository file validation before installation

### Security

- All temporary files now created with restrictive permissions
- Activation key masking in logs (only first 4 characters visible)
- Secure configuration file creation with proper umask

## [1.2.0] - 2025-09-15

### Added

- **True unattended automation**: `--assume-yes` flag now passes `-y` to convert2rhel tool
- Environment variable support for all configuration options
- Custom log file path support via `LOG_FILE` environment variable
- Enhanced error handling with specific exit codes for different failure scenarios
- Multiple Red Hat endpoint connectivity checks with redundancy
- Minimum disk space validation (5 GB requirement)
- Comprehensive pre-flight checks before conversion
- Detailed logging infrastructure with separate logs for analysis and conversion

### Changed

- Improved confirmation prompts with better messaging
- Enhanced credential validation with numeric check for organization ID
- Better handling of EOF in confirmation prompts
- Improved temporary directory handling with automatic cleanup
- Updated documentation with unattended mode examples

### Fixed

- `--assume-yes` flag now properly enables fully automated execution
- Previously would hang at convert2rhel's internal prompts (now fixed)
- Better error messages for missing required parameters
- Improved handling of package manager detection

### Deprecated

- None

### Security

- Enhanced credential masking in log files
- Secure permissions on configuration files (600)
- Validation of downloaded GPG keys and repository files

## [1.1.0] - 2025-08-01

### Added

- Analysis-only mode (`--analyze-only`) for pre-conversion testing
- Skip analysis mode (`--skip-analysis`) for advanced use cases
- Assume-yes mode (`--assume-yes`) for scripted automation (partial - script prompts only)
- Base package installation (tmux, vim, wget, curl, sos)
- Red Hat Insights client automatic setup and registration
- Comprehensive logging with timestamps
- Repository configuration backup before modification
- GPG key validation before installation

### Changed

- Restructured code into logical phases (preflight, installation, analysis, conversion, post-conversion)
- Improved error messages and user feedback
- Enhanced documentation with detailed examples

### Fixed

- Better handling of existing configuration files
- Improved package manager detection (dnf/yum)
- Fixed RHEL version detection logic

## [1.0.0] - 2025-07-01

### Added

- Initial release
- Basic convert2rhel setup automation
- Organization ID and activation key configuration
- RHEL version detection (7, 8, 9)
- Package manager detection (yum/dnf)
- GPG key installation
- convert2rhel repository configuration
- Basic conversion execution
- Simple logging
- Command-line argument parsing
- Help documentation

### Security

- Basic credential handling
- Configuration file creation

---

## Release Notes

### Version 1.3.0 Highlights

This release focuses on **enhanced usability** and **enterprise readiness**:

1. **Verbose Mode**: New `-v` flag allows real-time viewing of package installation output, making troubleshooting faster during interactive sessions.

2. **Flexible Installation**: New `--skip-base-packages` flag allows users to skip optional utility packages, useful for minimal environments or compliance requirements.

3. **Cloud Platform Examples**: Production-ready Terraform configurations for AWS, GCP, and Azure with comprehensive documentation.

4. **Ansible Integration**: Complete Ansible playbook with vault integration, pre-flight checks, and post-conversion validation.

5. **Improved Error Handling**: Better error messages, individual package installation handling, and graceful degradation for optional components.

### Upgrade Path

No breaking changes from 1.2.0 → 1.3.0. Simply download the new version:

```bash
curl -fsSL -o convert2rhel-setup https://raw.githubusercontent.com/khodaparastan/convert2rhel-automation/main/convert2rhel-setup
chmod +x convert2rhel-setup
```

### Version 1.2.0 Highlights

**Critical Fix**: The `--assume-yes` flag now properly passes `-y` to the convert2rhel tool, enabling **true unattended automation**. Previous versions would hang at convert2rhel's internal prompts even when `--assume-yes` was used.

**Breaking Change**: If you were using version 1.1.0 with `--assume-yes` in automation, you may have been handling convert2rhel prompts separately. Update your automation to rely on the script's built-in unattended mode.

### Version 1.1.0 Highlights

Added major workflow flexibility with analysis-only and skip-analysis modes, making the tool suitable for both cautious production environments and rapid testing scenarios.

### Version 1.0.0 Highlights

Initial stable release with core functionality for automated RHEL conversion.

---

## Support

For issues, questions, or feature requests:

- **GitHub Issues**: [khodaparastan/convert2rhel-automation](https://github.com/khodaparastan/convert2rhel-automation/issues)
- **Red Hat Support**: [access.redhat.com/support](https://access.redhat.com/support)
- **Documentation**: [README.md](README.md)

---

[1.3.0]: https://github.com/khodaparastan/convert2rhel-automation/releases/tag/v1.3.0
[1.2.0]: https://github.com/khodaparastan/convert2rhel-automation/releases/tag/v1.2.0
[1.1.0]: https://github.com/khodaparastan/convert2rhel-automation/releases/tag/v1.1.0
[1.0.0]: https://github.com/khodaparastan/convert2rhel-automation/releases/tag/v1.0.0
