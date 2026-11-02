#!/bin/bash

# TrustPin Flutter SDK Release Script
# Usage: ./release.sh <version>
# Example: ./release.sh 1.0.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate semver format
validate_semver() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
        log_error "Invalid semver format: $version"
        log_error "Expected format: MAJOR.MINOR.PATCH (e.g., 1.0.0, 2.1.0-beta.1)"
        exit 1
    fi
}

# Get current version from pubspec.yaml
get_current_version() {
    grep "version:" pubspec.yaml | sed 's/version: //' | tr -d ' '
}

# Update version in pubspec.yaml
update_pubspec_version() {
    local new_version=$1
    log_info "Updating version in pubspec.yaml to $new_version"
    
    # Create backup
    cp pubspec.yaml pubspec.yaml.bak
    
    # Update version
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/version: .*/version: $new_version/" pubspec.yaml
    else
        # Linux
        sed -i "s/version: .*/version: $new_version/" pubspec.yaml
    fi
    
    # Verify change
    local updated_version=$(get_current_version)
    if [[ "$updated_version" != "$new_version" ]]; then
        log_error "Failed to update version in pubspec.yaml"
        mv pubspec.yaml.bak pubspec.yaml
        exit 1
    fi
    
    rm pubspec.yaml.bak
    log_success "Updated pubspec.yaml version to $new_version"
}

# Update version in the Android library's build.gradle
update_android_version() {
    local new_version=$1
    local gradle_file="android/build.gradle"

    if [[ -f "$gradle_file" ]]; then
        log_info "Updating version in Android build.gradle to $new_version"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^version = \".*\"/version = \"$new_version\"/" "$gradle_file"
        else
            sed -i "s/^version = \".*\"/version = \"$new_version\"/" "$gradle_file"
        fi

        log_success "Updated Android build.gradle version to $new_version"
    else
        log_error "Android build.gradle not found at $gradle_file"
        exit 1
    fi
}

# Update the trustpin_attest package: its version, its Android library
# version, and its trustpin_sdk constraint to the same MAJOR.MINOR line (the
# two plugins must resolve the same native SDK version).
update_attest_version() {
    local new_version=$1
    local pubspec="trustpin_attest/pubspec.yaml"
    local gradle_file="trustpin_attest/android/build.gradle"
    local core="${new_version%%[-+]*}"
    local major="${core%%.*}"
    local minor="$(echo "$core" | cut -d. -f2)"
    local constraint="'>=${major}.${minor}.0 <${major}.$((minor + 1)).0'"

    if [[ ! -f "$pubspec" || ! -f "$gradle_file" ]]; then
        log_error "trustpin_attest package not found"
        exit 1
    fi
    log_info "Updating trustpin_attest to $new_version (trustpin_sdk $constraint)"

    local sed_inplace=(-i)
    [[ "$OSTYPE" == "darwin"* ]] && sed_inplace=(-i '')
    sed "${sed_inplace[@]}" "s/^version: .*/version: $new_version/" "$pubspec"
    sed "${sed_inplace[@]}" "s/^  trustpin_sdk: .*/  trustpin_sdk: $constraint/" "$pubspec"
    sed "${sed_inplace[@]}" "s/^version = \".*\"/version = \"$new_version\"/" "$gradle_file"

    if ! grep -q "^version: $new_version$" "$pubspec"; then
        log_error "Failed to update version in $pubspec"
        exit 1
    fi
    log_success "Updated trustpin_attest to $new_version"
}

# Check if a changelog (default CHANGELOG.md) contains the new version
check_changelog() {
    local new_version=$1
    local changelog="${2:-CHANGELOG.md}"
    
    log_info "Checking if $changelog contains version $new_version"
    
    if [[ ! -f "$changelog" ]]; then
        log_error "$changelog not found"
        log_error "Please create $changelog and add an entry for version $new_version"
        return 1
    fi
    
    # Check if the version exists in the changelog
    if grep -q "## \[$new_version\]" "$changelog"; then
        log_success "Found version $new_version in $changelog"
        return 0
    elif grep -q "## $new_version" "$changelog"; then
        log_success "Found version $new_version in $changelog"
        return 0
    else
        log_error "Version $new_version not found in $changelog"
        log_error "Please add a changelog entry for version $new_version before releasing"
        log_error ""
        log_error "Expected format:"
        log_error "## [$new_version] - $(date +%Y-%m-%d)"
        log_error ""
        log_error "### Added"
        log_error "- New feature descriptions"
        log_error ""
        log_error "### Changed"
        log_error "- Changed feature descriptions"
        log_error ""
        log_error "### Fixed"
        log_error "- Bug fix descriptions"
        log_error ""
        return 1
    fi
}

# Generate documentation
generate_docs() {
    log_info "Generating API documentation..."

    # Clean previous docs (preserve .nojekyll for GitHub Pages)
    rm -rf docs/
    mkdir -p docs/

    # Generate new docs
    if dart doc --output=docs; then
        # Required so GitHub Pages serves files starting with underscores (e.g. __404error.html)
        touch docs/.nojekyll
        log_success "Generated API documentation in docs/ directory"
    else
        log_error "Failed to generate documentation"
        exit 1
    fi

    # Check if there are changes to commit
    if [[ -n "$(git status --porcelain docs/)" ]]; then
        log_info "Documentation changes detected, committing..."
        git add docs/
        if git commit -m "docs: update API documentation"; then
            log_success "Documentation changes committed"
        else
            log_error "Failed to commit documentation changes"
            exit 1
        fi
    else
        log_info "No documentation changes to commit"
    fi
}

# Run all tests
run_tests() {
    log_info "Running all tests..."
    
    # Run unit tests
    log_info "Running unit tests..."
    if flutter test; then
        log_success "Unit tests passed"
    else
        log_error "Unit tests failed"
        exit 1
    fi

    # Run all tests in test directory with coverage if available
    if command -v lcov >/dev/null 2>&1; then
        log_info "Running tests with coverage..."
        if flutter test --coverage; then
            log_success "Tests with coverage completed"
            if [[ -f "coverage/lcov.info" ]]; then
                log_info "Coverage report generated: coverage/lcov.info"
            fi
        else
            log_warning "Tests with coverage failed, but continuing..."
        fi
    else
        log_info "lcov not available, skipping coverage report"
    fi
    
    # Check for integration tests but skip them in release process
    if [[ -d "example/integration_test" ]]; then
        log_warning "Integration tests found but skipped during release process"
        log_info "Integration tests require emulator/device and should be run manually"
        log_info "To run integration tests separately:"
        log_info "  1. Start an emulator: flutter emulators --launch <emulator_id>"
        log_info "  2. cd example && flutter clean && flutter pub get"
        log_info "  3. flutter test integration_test/plugin_integration_test.dart"
        log_info ""
        log_info "Integration tests are designed for development/CI environments with emulators"
    fi
    
    # Run example app tests if they exist
    if [[ -d "example/test" && -n "$(ls -A example/test 2>/dev/null)" ]]; then
        log_info "Running example app tests..."
        (
            cd example
            if flutter test; then
                log_success "Example app tests passed"
            else
                log_error "Example app tests failed"
                exit 1
            fi
        )
    fi
    
    # Run the trustpin_attest package's tests
    log_info "Running trustpin_attest tests..."
    (
        cd trustpin_attest
        flutter pub get >/dev/null
        if flutter test; then
            log_success "trustpin_attest tests passed"
        else
            log_error "trustpin_attest tests failed"
            exit 1
        fi
    )

    # Run sample app tests if they exist
    if [[ -d "sample_app/test" && -n "$(ls -A sample_app/test 2>/dev/null)" ]]; then
        log_info "Running sample app tests..."
        (
            cd sample_app
            if flutter test; then
                log_success "Sample app tests passed"
            else
                log_error "Sample app tests failed"
                exit 1
            fi
        )
    fi
    
    log_success "All available tests completed successfully"
}

# Run static analysis
run_analysis() {
    log_info "Running static analysis..."
    
    if dart analyze --fatal-infos; then
        log_success "Static analysis passed"
    else
        log_error "Static analysis failed"
        exit 1
    fi

    if (cd trustpin_attest && dart analyze --fatal-infos); then
        log_success "trustpin_attest static analysis passed"
    else
        log_error "trustpin_attest static analysis failed"
        exit 1
    fi
}

# Validate pub package
validate_package() {
    log_info "Validating package for pub.dev..."
    
    if dart pub publish --dry-run; then
        log_success "Package validation passed"
    else
        log_error "Package validation failed"
        exit 1
    fi
}

# Main function
main() {
    # Check if version argument is provided
    if [[ $# -eq 0 ]]; then
        log_error "Version argument is required"
        echo "Usage: $0 <version>"
        echo "Example: $0 1.0.0"
        exit 1
    fi
    
    local new_version=$1
    
    # Validate inputs
    validate_semver "$new_version"
    
    # Check if we're in a Flutter project
    if [[ ! -f "pubspec.yaml" ]]; then
        log_error "pubspec.yaml not found. Are you in a Flutter project directory?"
        exit 1
    fi
    
    # Check if we're in a git repository
    if [[ ! -d ".git" ]]; then
        log_error "Not in a git repository. This script requires git for changelog generation."
        exit 1
    fi
    
    # Get current version
    local current_version=$(get_current_version)
    log_info "Current version: $current_version"
    log_info "New version: $new_version"
    
    # Confirm with user
    echo
    log_warning "This will:"
    echo "  1. Update version in pubspec.yaml and android/build.gradle, and in"
    echo "     trustpin_attest (pubspec, android/build.gradle, trustpin_sdk range)"
    echo "  2. Check that both CHANGELOG.md files contain version $new_version"
    echo "  3. Run comprehensive test suite (unit tests only)"
    echo "  4. Generate API documentation"
    echo "  5. Run static analysis and package validation"
    echo ""
    log_info "Note: Integration tests are skipped (require emulator/device)"
    echo
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Release cancelled by user"
        exit 0
    fi
    
    echo
    log_info "Starting release process for version $new_version..."
    echo "=================================================="
    
    # Step 1: Update versions
    log_info "Step 1: Updating versions..."
    update_pubspec_version "$new_version"
    update_android_version "$new_version"
    update_attest_version "$new_version"
    
    # Step 2: Check changelog
    log_info "Step 2: Checking changelogs..."
    if ! check_changelog "$new_version"; then
        exit 1
    fi
    if ! check_changelog "$new_version" trustpin_attest/CHANGELOG.md; then
        exit 1
    fi
    
    # Step 3: Run tests
    log_info "Step 3: Running tests..."
    run_tests
    
    # Step 4: Run static analysis
    log_info "Step 4: Running static analysis..."
    run_analysis
    
    # Step 5: Generate documentation
    log_info "Step 5: Generating documentation..."
    generate_docs
    
    # Step 6: Validate package
    log_info "Step 6: Validating package..."
    validate_package
    
    echo
    echo "=================================================="
    log_success "Release preparation completed successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Review the changes:"
    echo "     - pubspec.yaml, trustpin_attest/pubspec.yaml"
    echo "     - docs/ directory"
    echo "  2. Commit the changes:"
    echo "     git add ."
    echo "     git commit -m \"chore: release version $new_version\""
    echo "  3. Create and push a tag:"
    echo "     git tag v$new_version"
    echo "     git push origin main --tags"
    echo "  4. Publish to pub.dev, in this order:"
    echo "     dart pub publish                       # trustpin_sdk"
    echo "     trustpin_attest/tool/publish.sh        # needs trustpin_sdk $new_version on pub.dev"
    echo "  5. Deploy docs to GitHub Pages (if configured)"
    echo
}

# Run main function with all arguments
main "$@"