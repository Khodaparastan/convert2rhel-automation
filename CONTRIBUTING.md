# Contributing to Convert2RHEL Automation

Thank you for your interest in contributing to Convert2RHEL Automation! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please be respectful and constructive in all interactions.

### Our Standards

- **Be Respectful**: Treat everyone with respect and consideration
- **Be Collaborative**: Work together openly and constructively
- **Be Professional**: Keep discussions focused and productive
- **Be Inclusive**: Welcome diverse perspectives and backgrounds

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- A GitHub account
- `git` installed and configured
- `bash` 4.0 or higher
- `shellcheck` for script linting
- A test environment (VM or container) for testing conversions

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

   ```bash
   git clone https://github.com/YOUR-USERNAME/convert2rhel-automation.git
   cd convert2rhel-automation
   ```

3. Add the upstream repository:

   ```bash
   git remote add upstream https://github.com/khodaparastan/convert2rhel-automation.git
   ```

## Development Setup

### Environment Setup

1. **Install ShellCheck** (for linting):

   ```bash
   # macOS
   brew install shellcheck

   # Ubuntu/Debian
   sudo apt-get install shellcheck

   # RHEL/CentOS
   sudo yum install shellcheck
   ```

2. **Set up a test environment**:

   - Use VirtualBox, VMware, or cloud instances
   - Recommended: Use snapshots before testing
   - Test on CentOS, AlmaLinux, Rocky Linux, or Oracle Linux

### Verify Your Setup

```bash
# Check shellcheck installation
shellcheck --version

# Lint the main script
shellcheck convert2rhel-setup

# Verify script syntax
bash -n convert2rhel-setup
```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

1. **Bug Fixes**: Fix issues reported in GitHub Issues
2. **Feature Additions**: Add new functionality (discuss first in an issue)
3. **Documentation**: Improve README, examples, or inline documentation
4. **Examples**: Add Terraform/Ansible/other automation examples
5. **Testing**: Improve test coverage or add test cases
6. **Performance**: Optimize script performance or resource usage

### Contribution Workflow

1. **Create an Issue** (for features or major changes):
   - Describe the feature or bug
   - Wait for maintainer feedback
   - Get approval before starting work

2. **Create a Branch**:

   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/bug-description
   ```

3. **Make Your Changes**:
   - Follow coding standards (see below)
   - Add/update documentation
   - Test thoroughly

4. **Commit Your Changes**:

   ```bash
   git add .
   git commit -m "Type: Brief description

   Detailed explanation of changes.

   Fixes #123"
   ```

5. **Push to Your Fork**:

   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request**:
   - Use a clear, descriptive title
   - Reference related issues
   - Describe what changed and why
   - Include testing details

## Coding Standards

### Bash Script Standards

This project follows **enterprise-grade Bash scripting practices**:

#### General Rules

```bash
# Use strict mode
set -o errexit   # Exit on error
set -o nounset   # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Use meaningful variable names
readonly MAX_RETRIES=3
local retry_count=0

# Use functions for reusable code
validate_input() {
    local input="$1"
    # validation logic
}

# Always quote variables
echo "${variable}"
```

#### Naming Conventions

- **Functions**: `snake_case` (e.g., `install_package`, `check_connectivity`)
- **Variables**: `snake_case` for local, `UPPER_CASE` for constants/globals
- **Files**: `kebab-case` (e.g., `convert2rhel-setup`)

#### ShellCheck Compliance

All code must pass ShellCheck with no warnings:

```bash
shellcheck convert2rhel-setup
```

Common issues to avoid:

```bash
# ❌ Bad: Unquoted variables
for file in $FILES; do

# ✅ Good: Quoted variables
for file in "${FILES[@]}"; do

# ❌ Bad: Using backticks
output=`command`

# ✅ Good: Using $()
output="$(command)"

# ❌ Bad: Not checking command success
curl https://example.com/file

# ✅ Good: Checking command success
if ! curl https://example.com/file; then
    die "Failed to download file"
fi
```

#### Error Handling

```bash
# Always handle errors explicitly
if ! some_command; then
    log_error "Command failed: some_command"
    return "${EXIT_ERROR}"
fi

# Use meaningful exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1
readonly EXIT_INVALID_ARGS=2
readonly EXIT_PREREQ_FAILED=3
```

#### Logging

```bash
# Use consistent logging functions
log_info "Starting process..."
log_success "Process completed"
log_warning "Non-critical issue detected"
log_error "Critical error occurred"

# Always log to file with timestamps
log_to_file "INFO" "Message content"
```

#### Comments and Documentation

```bash
# Function documentation format:
# Brief description of what the function does
#
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument
#
# Returns:
#   0 on success, non-zero on failure
#
# Example:
#   validate_input "test-value"
function_name() {
    # Implementation
}
```

### Documentation Standards

#### README Updates

When adding features:

1. Update relevant sections in README.md
2. Add examples demonstrating the feature
3. Update the table of contents if adding sections
4. Include troubleshooting guidance if applicable

#### CHANGELOG Updates

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

### Added
- New feature description

### Changed
- Changed feature description

### Fixed
- Bug fix description
```

#### Code Comments

```bash
# Good comments explain WHY, not WHAT
# Bad: Download the file
curl -o file.txt https://example.com/file.txt

# Good: Download config from CDN to ensure latest version
curl -o file.txt https://example.com/file.txt

# Use section headers for major sections
# ============================================================================
# Installation Functions
# ============================================================================
```

## Testing

### Required Testing

Before submitting a PR, test:

1. **Syntax Check**:

   ```bash
   bash -n convert2rhel-setup
   ```

2. **Linting**:

   ```bash
   shellcheck convert2rhel-setup
   ```

3. **Analysis Mode** (safe testing):

   ```bash
   sudo ./convert2rhel-setup \
     --org-id YOUR_ORG_ID \
     --activation-key YOUR_KEY \
     --analyze-only
   ```

4. **Dry Run** (if applicable):
   Test in a disposable VM with snapshots

### Test Environments

Test on at least one of:

- CentOS Linux 7.9
- CentOS Linux 8.5
- AlmaLinux 8.10 or 9.6
- Rocky Linux 8.10 or 9.6
- Oracle Linux 7.9, 8.10, or 9.6

### Test Checklist

- [ ] Script passes ShellCheck with no warnings
- [ ] All command-line flags work as expected
- [ ] Help message displays correctly
- [ ] Error messages are clear and helpful
- [ ] Exit codes are appropriate
- [ ] Logging works correctly
- [ ] Analysis mode completes successfully
- [ ] Documentation updated
- [ ] Examples tested (if applicable)

## Submitting Changes

### Pull Request Guidelines

**PR Title Format:**

```
Type: Brief description

Examples:
- feat: Add support for custom repository URLs
- fix: Correct disk space calculation on XFS
- docs: Update Ansible playbook examples
- refactor: Improve error handling in validation
```

**PR Description Template:**

```markdown
## Description
Brief summary of changes

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update

## Testing
Describe testing performed:
- Environment: CentOS 8.5 VM
- Commands run: ...
- Results: ...

## Checklist
- [ ] Code follows project style guidelines
- [ ] ShellCheck passes with no warnings
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Tested in appropriate environment
- [ ] All tests pass

## Related Issues
Fixes #123
Relates to #456
```

### Review Process

1. Maintainer reviews code and documentation
2. Automated checks run (linting, syntax)
3. Feedback provided via PR comments
4. Changes requested or approved
5. Merge when approved

### After Your PR is Merged

1. Delete your feature branch
2. Update your fork:

   ```bash
   git checkout main
   git pull upstream main
   git push origin main
   ```

## Reporting Bugs

### Before Reporting

1. Check existing issues for duplicates
2. Verify you're using the latest version
3. Test in a clean environment if possible

### Bug Report Template

```markdown
**Describe the Bug**
Clear description of the issue

**To Reproduce**
Steps to reproduce:
1. Run command: `./convert2rhel-setup ...`
2. Observe error at step X
3. See error message

**Expected Behavior**
What should have happened

**Environment**
- OS: CentOS 8.5
- Script Version: 1.3.0
- Shell: bash 4.4.20

**Logs**
```

Paste relevant log excerpts

```

**Additional Context**
Any other relevant information
```

## Suggesting Enhancements

### Enhancement Request Template

```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed? Who will benefit?

**Proposed Solution**
How should this work?

**Alternatives Considered**
Other approaches you've thought about

**Additional Context**
Screenshots, examples, references
```

## Development Best Practices

### Security

- Never commit credentials or secrets
- Use environment variables for sensitive data
- Validate all user inputs
- Use secure file permissions (600 for config files)
- Mask sensitive data in logs

### Performance

- Minimize external command calls
- Use built-in Bash features when possible
- Cache results of expensive operations
- Avoid unnecessary loops

### Compatibility

- Support Bash 4.0+
- Test on multiple RHEL-compatible distributions
- Handle both yum and dnf package managers
- Support both x86_64 and aarch64 architectures

## Questions?

If you have questions:

1. Check existing documentation (README.md, QUICK_REFERENCE.md)
2. Search existing issues
3. Open a new issue with the "question" label

## Release Process (For Maintainers)

### Automated Release Script

The project includes an automated release script that handles the entire release process:

```bash
./release.sh VERSION
```

**Example:**

```bash
./release.sh 1.3.0
```

The script performs:

- ✅ Version format validation
- ✅ Prerequisites check (git, shellcheck, sha256sum)
- ✅ Git status verification
- ✅ ShellCheck and syntax validation
- ✅ Security scanning (hardcoded credentials, TODO/FIXME)
- ✅ Version consistency checks across all files
- ✅ CHANGELOG validation
- ✅ Git commit and tag creation
- ✅ Checksum generation (SHA256)
- ✅ Release notes extraction
- ✅ Optional push to remote

**Generated Files:**

- `convert2rhel-setup.sha256` - SHA256 checksum
- `release-notes-vX.Y.Z.md` - Extracted release notes for GitHub

### Manual Release Steps

If you prefer manual releases or need to troubleshoot:

1. **Update Version Numbers:**

   ```bash
   # Update version in:
   # - convert2rhel-setup (SCRIPT_VERSION)
   # - README.md
   # - QUICK_REFERENCE.md
   # - SECURITY.md
   # - CHANGELOG.md
   # - examples/ansible-playbook.yml
   ```

2. **Update CHANGELOG.md:**

   ```markdown
   ## [X.Y.Z] - YYYY-MM-DD

   ### Added
   - New features

   ### Changed
   - Modifications

   ### Fixed
   - Bug fixes

   ### Security
   - Security improvements
   ```

3. **Run Quality Checks:**

   ```bash
   shellcheck convert2rhel-setup
   bash -n convert2rhel-setup
   ```

4. **Commit and Tag:**

   ```bash
   git add .
   git commit -m "Release vX.Y.Z"
   git tag -a vX.Y.Z -m "Version X.Y.Z"
   git push origin main
   git push origin vX.Y.Z
   ```

5. **Generate Checksum:**

   ```bash
   sha256sum convert2rhel-setup > convert2rhel-setup.sha256
   ```

6. **Create GitHub Release:**
   - Go to repository releases page
   - Select tag vX.Y.Z
   - Copy description from CHANGELOG.md
   - Attach convert2rhel-setup and checksum file

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

**Thank you for contributing to Convert2RHEL Automation!**
