#!/usr/bin/env bash
#
# release.sh - Automated release script for convert2rhel-automation
#
# This script automates the release process including:
# - Version validation
# - Code quality checks
# - Security scanning
# - Git operations
# - Checksum generation
# - Release notes preparation
#
# Usage: ./release.sh [VERSION]
# Example: ./release.sh 1.3.0
#

set -o errexit
set -o nounset
set -o pipefail

# ============================================================================
# Configuration
# ============================================================================

# shellcheck disable=SC2155
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_DIR}"
readonly MAIN_SCRIPT="convert2rhel-setup"
readonly CHANGELOG="CHANGELOG.md"
readonly README="README.md"
readonly QUICK_REF="QUICK_REFERENCE.md"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

log_info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$*"
}

log_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$*"
}

log_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$*"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$*" >&2
}

die() {
    log_error "$*"
    exit 1
}

print_header() {
    local title="$1"
    printf '\n%b╔════════════════════════════════════════════════════════════════════╗%b\n' "${BOLD}" "${NC}"
    printf '%b║ %-66s ║%b\n' "${BOLD}" "$title" "${NC}"
    printf '%b╚════════════════════════════════════════════════════════════════════╝%b\n\n' "${BOLD}" "${NC}"
}

confirm() {
    local prompt="$1"
    local response

    printf "${YELLOW}%s [y/N]: ${NC}" "$prompt"
    read -r response

    case "${response,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# ============================================================================
# Validation Functions
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing=()
    local tools=("git" "shellcheck" "sha256sum" "grep" "sed" "awk")

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$tool")
            log_error "Missing required tool: $tool"
        else
            log_success "Found: $tool"
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        die "Missing required tools: ${missing[*]}"
    fi

    # Check git status
    if [[ ! -d .git ]]; then
        die "Not in a git repository"
    fi

    log_success "All prerequisites satisfied"
}

validate_version() {
    local version="$1"

    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        die "Invalid version format: $version (expected: X.Y.Z)"
    fi

    log_success "Version format valid: $version"
}

check_git_status() {
    print_header "Checking Git Status"

    # Check for uncommitted changes (excluding new release files)
    local uncommitted
    uncommitted=$(git status --porcelain | grep -v '^??' || true)

    if [[ -n "$uncommitted" ]]; then
        log_warning "Uncommitted changes detected:"
        git status --short

        if ! confirm "Continue with uncommitted changes?"; then
            die "Aborting due to uncommitted changes"
        fi
    else
        log_success "Working directory clean"
    fi

    # Check if on main/master branch
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)

    if [[ "$branch" != "main" && "$branch" != "master" ]]; then
        log_warning "Not on main/master branch (current: $branch)"

        if ! confirm "Continue on branch '$branch'?"; then
            die "Aborting - switch to main/master branch"
        fi
    else
        log_success "On branch: $branch"
    fi

    # Check if remote is configured
    if ! git remote get-url origin &>/dev/null; then
        log_warning "No 'origin' remote configured"
    else
        log_success "Remote 'origin' configured: $(git remote get-url origin)"
    fi
}

# ============================================================================
# Code Quality Checks
# ============================================================================

run_shellcheck() {
    print_header "Running ShellCheck"

    if ! shellcheck "$MAIN_SCRIPT"; then
        die "ShellCheck failed - fix issues before releasing"
    fi

    log_success "ShellCheck passed"
}

validate_bash_syntax() {
    print_header "Validating Bash Syntax"

    if ! bash -n "$MAIN_SCRIPT"; then
        die "Bash syntax validation failed"
    fi

    log_success "Bash syntax valid"
}

check_security() {
    print_header "Security Checks"

    # Check for hardcoded credentials
    local security_patterns=(
        'password.*=.*["\047][^"\047]+["\047]'
        'secret.*=.*["\047][^"\047]+["\047]'
        'api[_-]?key.*=.*["\047][^"\047]+["\047]'
        'token.*=.*["\047][^"\047]+["\047]'
    )

    local found_issues=0
    local exclude_dirs=(".git" ".terraform" ".idea" ".vscode" "node_modules")
    local exclude_args=()

    for dir in "${exclude_dirs[@]}"; do
        exclude_args+=("--exclude-dir=$dir")
    done

    for pattern in "${security_patterns[@]}"; do
        if grep -rniE "$pattern" . "${exclude_args[@]}" --exclude="release.sh" --exclude="*.md" --binary-files=without-match 2>/dev/null; then
            log_error "Found potential hardcoded credentials matching: $pattern"
            ((found_issues++)) || true
        fi
    done

    if [[ $found_issues -gt 0 ]]; then
        die "Security check failed - found $found_issues potential issues"
    fi

    # Check for TODO/FIXME in code
    local todos
    todos=$(grep -rn "TODO\|FIXME\|XXX\|HACK" "$MAIN_SCRIPT" || true)

    if [[ -n "$todos" ]]; then
        log_warning "Found TODO/FIXME comments in code:"
        echo "$todos"

        if ! confirm "Continue with TODO/FIXME comments?"; then
            die "Fix TODO/FIXME comments before releasing"
        fi
    fi

    log_success "Security checks passed"
}

# ============================================================================
# Version Consistency Checks
# ============================================================================

check_version_consistency() {
    local version="$1"
    print_header "Checking Version Consistency"

    local files=(
        "$MAIN_SCRIPT:Version: $version"
        "$README:Version:** $version"
        "$QUICK_REF:Version:** $version"
        "SECURITY.md:Version:** $version"
    )

    local inconsistent=0
    for file_pattern in "${files[@]}"; do
        local file="${file_pattern%%:*}"
        local pattern="${file_pattern#*:}"

        if [[ ! -f "$file" ]]; then
            log_error "File not found: $file"
            ((inconsistent++)) || true
            continue
        fi

        if ! grep -q "$pattern" "$file"; then
            log_error "Version mismatch in $file (expected: $pattern)"
            ((inconsistent++)) || true
        else
            log_success "$file: version correct"
        fi
    done

    if [[ $inconsistent -gt 0 ]]; then
        die "Version inconsistencies found in $inconsistent file(s)"
    fi

    log_success "All version numbers consistent: $version"
}

check_changelog() {
    local version="$1"
    print_header "Checking CHANGELOG"

    if [[ ! -f "$CHANGELOG" ]]; then
        die "CHANGELOG.md not found"
    fi

    # Check if version exists in CHANGELOG
    if ! grep -q "## \[$version\]" "$CHANGELOG"; then
        log_error "Version $version not found in CHANGELOG.md"
        log_info "Please add release notes for version $version"
        die "CHANGELOG.md missing entry for $version"
    fi

    # Check if date is present
    local today
    today=$(date +%Y-%m-%d)

    if ! grep -q "## \[$version\] - $today" "$CHANGELOG"; then
        log_warning "CHANGELOG date may not match today ($today)"
    fi

    log_success "CHANGELOG.md contains entry for $version"
}

# ============================================================================
# Release Operations
# ============================================================================

generate_checksums() {
    local version="$1"
    print_header "Generating Checksums"

    local checksum_file="${MAIN_SCRIPT}.sha256"

    if sha256sum "$MAIN_SCRIPT" > "$checksum_file"; then
        log_success "Checksum generated: $checksum_file"
        cat "$checksum_file"
    else
        die "Failed to generate checksum"
    fi
}

create_git_tag() {
    local version="$1"
    local tag="v${version}"

    print_header "Creating Git Tag"

    # Check if tag already exists
    if git rev-parse "$tag" &>/dev/null; then
        log_error "Tag $tag already exists"

        if confirm "Delete existing tag and recreate?"; then
            git tag -d "$tag"
            log_info "Deleted existing tag: $tag"
        else
            die "Tag already exists - aborting"
        fi
    fi

    # Create annotated tag
    local tag_message="Version $version - Enhanced automation and documentation"

    if git tag -a "$tag" -m "$tag_message"; then
        log_success "Created tag: $tag"
    else
        die "Failed to create tag"
    fi
}

stage_release_files() {
    print_header "Staging Release Files"

    local files=(
        "$MAIN_SCRIPT"
        "$CHANGELOG"
        "$README"
        "$QUICK_REF"
        "LICENSE"
        "CONTRIBUTING.md"
        "SECURITY.md"
        ".gitignore"
        "examples/ansible-playbook.yml"
    )

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            git add "$file"
            log_success "Staged: $file"
        else
            log_warning "File not found (skipping): $file"
        fi
    done
}

create_commit() {
    local version="$1"
    print_header "Creating Release Commit"

    # Check if there are staged changes
    if ! git diff --cached --quiet; then
        local commit_message="Release v${version}

Added:
- Verbose mode for real-time package manager output
- Skip base packages option for minimal installations
- ARM64/aarch64 architecture support
- Production-ready Terraform examples (AWS, GCP, Azure)
- Comprehensive project documentation (LICENSE, CHANGELOG, CONTRIBUTING, SECURITY)

Changed:
- Enhanced error handling and user feedback
- Improved .gitignore with comprehensive exclusions
- Updated Ansible playbook to v${version}
- Better package installation with individual error handling

Fixed:
- Color support detection with fallbacks
- Secure temporary file creation

Security:
- Added comprehensive security policy
- Enhanced file permission handling"

        if git commit -m "$commit_message"; then
            log_success "Created release commit"
        else
            die "Failed to create commit"
        fi
    else
        log_warning "No changes to commit"
    fi
}

generate_release_notes() {
    local version="$1"
    local output_file="release-notes-v${version}.md"

    print_header "Generating Release Notes"

    # Extract release notes from CHANGELOG
    if awk "/## \[${version}\]/,/## \[/ {print}" "$CHANGELOG" | grep -v "^## \[[0-9]" > "$output_file"; then
        log_success "Release notes saved to: $output_file"
        log_info "Preview:"
        head -20 "$output_file"
    else
        log_warning "Could not extract release notes from CHANGELOG"
    fi
}

push_release() {
    local version="$1"
    local tag="v${version}"

    print_header "Pushing Release"

    log_warning "This will push commits and tags to the remote repository"

    if ! confirm "Push release to remote?"; then
        log_warning "Skipping push - you can push manually later with:"
        log_info "  git push origin main"
        log_info "  git push origin $tag"
        return
    fi

    # Push commits
    if git push origin "$(git rev-parse --abbrev-ref HEAD)"; then
        log_success "Pushed commits to remote"
    else
        log_error "Failed to push commits"
    fi

    # Push tag
    if git push origin "$tag"; then
        log_success "Pushed tag to remote: $tag"
    else
        log_error "Failed to push tag"
    fi
}

# ============================================================================
# Main Release Flow
# ============================================================================

print_release_summary() {
    local version="$1"

    cat <<EOF

${BOLD}╔════════════════════════════════════════════════════════════════════╗
║                     RELEASE SUMMARY - v${version}                        ║
╚════════════════════════════════════════════════════════════════════╝${NC}

${GREEN}✅ All checks passed${NC}
${GREEN}✅ Version consistency verified${NC}
${GREEN}✅ Git tag created: v${version}${NC}
${GREEN}✅ Checksums generated${NC}
${GREEN}✅ Release notes prepared${NC}

${BOLD}Next Steps:${NC}

1. ${BOLD}Create GitHub Release:${NC}
   - Go to: https://github.com/khodaparastan/convert2rhel-automation/releases/new
   - Select tag: v${version}
   - Title: "v${version} - Enhanced Automation & Cloud Examples"
   - Copy description from: release-notes-v${version}.md
   - Attach: ${MAIN_SCRIPT} and ${MAIN_SCRIPT}.sha256

2. ${BOLD}Verify Release:${NC}
   - Check GitHub release page
   - Test download link
   - Verify checksum matches

3. ${BOLD}Announce Release:${NC}
   - Update documentation sites
   - Notify users/contributors
   - Share on relevant channels

${BOLD}Files Generated:${NC}
- ${MAIN_SCRIPT}.sha256 (checksum)
- release-notes-v${version}.md (GitHub release notes)

${GREEN}Release process completed successfully!${NC}

EOF
}

main() {
    cd "$PROJECT_ROOT"

    # Parse version argument
    if [[ $# -ne 1 ]]; then
        cat <<EOF
${BOLD}Convert2RHEL Automation - Release Script${NC}

Usage: $0 VERSION

Example:
  $0 1.3.0

This script will:
  1. Validate prerequisites and version format
  2. Run code quality checks (ShellCheck, syntax)
  3. Perform security scanning
  4. Verify version consistency across files
  5. Check CHANGELOG entry
  6. Create git commit and tag
  7. Generate checksums
  8. Prepare release notes
  9. Push to remote (optional)

EOF
        exit 1
    fi

    local version="$1"

    print_header "Convert2RHEL Automation Release Script v${version}"

    # Validation phase
    check_prerequisites
    validate_version "$version"
    check_git_status

    # Code quality phase
    run_shellcheck
    validate_bash_syntax
    check_security

    # Version consistency phase
    check_version_consistency "$version"
    check_changelog "$version"

    # Confirmation
    log_warning "Ready to create release v${version}"
    if ! confirm "Proceed with release?"; then
        die "Release cancelled by user"
    fi

    # Release operations
    stage_release_files
    create_commit "$version"
    create_git_tag "$version"
    generate_checksums "$version"
    generate_release_notes "$version"

    # Push (optional)
    push_release "$version"

    # Summary
    print_release_summary "$version"
}

# ============================================================================
# Script Entry Point
# ============================================================================

main "$@"

