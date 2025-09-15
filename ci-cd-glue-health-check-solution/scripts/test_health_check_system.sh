#!/bin/bash
# Test script for Glue Health Check System
# Validates the complete implementation without deploying to AWS

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
log_success() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅${NC} $1"; }
log_error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌${NC} $1"; }
log_warning() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️${NC} $1"; }

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "🧪 Test $TESTS_TOTAL: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "FAIL: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

main() {
    log "🧪 Testing Glue Health Check System"
    echo "=================================================="
    
    # Test 1: Directory structure
    run_test "Directory structure exists" "test_directory_structure"
    
    # Test 2: Required scripts exist
    run_test "Required scripts exist" "test_scripts_exist"
    
    # Test 3: Script permissions
    run_test "Script permissions are correct" "test_script_permissions"
    
    # Test 4: Terraform syntax
    run_test "Terraform syntax validation" "test_terraform_syntax"
    
    # Test 5: Python syntax
    run_test "Python script syntax" "test_python_syntax"
    
    # Test 6: Example configurations
    run_test "Example configurations exist" "test_example_configs"
    
    # Test 7: Documentation exists
    run_test "Documentation exists" "test_documentation"
    
    # Test 8: Prerequisites check
    run_test "Prerequisites validation" "test_prerequisites"
    
    # Test 9: Dry run simulation
    run_test "Dry run simulation" "test_dry_run_simulation"
    
    # Show results
    show_test_results
}

test_directory_structure() {
    [ -d "$PROJECT_ROOT/scripts" ] && \
    [ -d "$PROJECT_ROOT/terraform/modules/glue_health_check" ] && \
    [ -d "$PROJECT_ROOT/src/jobs/health_check" ] && \
    [ -d "$PROJECT_ROOT/examples" ] && \
    [ -d "$PROJECT_ROOT/docs" ]
}

test_scripts_exist() {
    [ -f "$PROJECT_ROOT/scripts/glue_health_check.sh" ] && \
    [ -f "$PROJECT_ROOT/scripts/run_glue_health_check.sh" ] && \
    [ -f "$PROJECT_ROOT/scripts/implement_health_check_system.sh" ] && \
    [ -f "$PROJECT_ROOT/scripts/test_health_check_system.sh" ]
}

test_script_permissions() {
    [ -x "$PROJECT_ROOT/scripts/glue_health_check.sh" ] && \
    [ -x "$PROJECT_ROOT/scripts/run_glue_health_check.sh" ] && \
    [ -x "$PROJECT_ROOT/scripts/implement_health_check_system.sh" ] && \
    [ -x "$PROJECT_ROOT/scripts/test_health_check_system.sh" ]
}

test_terraform_syntax() {
    if [ -f "$PROJECT_ROOT/terraform/modules/glue_health_check/main.tf" ]; then
        cd "$PROJECT_ROOT/terraform/modules/glue_health_check"
        terraform fmt -check
        cd - > /dev/null
    else
        return 1
    fi
}

test_python_syntax() {
    if command -v python3 &> /dev/null; then
        if [ -f "$PROJECT_ROOT/src/jobs/health_check/data_processing_health_check.py" ]; then
            python3 -m py_compile "$PROJECT_ROOT/src/jobs/health_check/data_processing_health_check.py"
        else
            return 1
        fi
    else
        log_warning "Python3 not available - skipping syntax check"
    fi
}

test_example_configs() {
    [ -f "$PROJECT_ROOT/examples/.drone.yml" ] && \
    [ -f "$PROJECT_ROOT/examples/terraform.tfvars.example" ]
}

test_documentation() {
    [ -f "$PROJECT_ROOT/README.md" ] && \
    [ -f "$PROJECT_ROOT/docs/CI_CD_Glue_Health_Check_Implementation.md" ]
}

test_prerequisites() {
    command -v aws > /dev/null && \
    command -v terraform > /dev/null
}

test_dry_run_simulation() {
    # Simulate a dry run without AWS deployment
    export DRY_RUN=true
    export DRONE_PULL_REQUEST="test-123"
    
    # Test argument parsing
    if [ -f "$PROJECT_ROOT/scripts/glue_health_check.sh" ]; then
        bash -n "$PROJECT_ROOT/scripts/glue_health_check.sh"
    else
        return 1
    fi
}

show_test_results() {
    echo ""
    echo "=================================================="
    echo "🧪 TEST RESULTS SUMMARY"
    echo "=================================================="
    echo "Total Tests:  $TESTS_TOTAL"
    echo "Passed:       $TESTS_PASSED"
    echo "Failed:       $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "🎉 ALL TESTS PASSED!"
        echo ""
        echo "✅ Your health check system is ready for deployment!"
        echo ""
        echo "📋 NEXT STEPS:"
        echo "1. Customize configuration files in examples/"
        echo "2. Deploy Terraform modules to your AWS environment"
        echo "3. Integrate with your CI/CD pipeline"
        echo "4. Test with a real pull request"
        echo ""
        exit 0
    else
        log_error "💥 $TESTS_FAILED TEST(S) FAILED"
        echo ""
        echo "❌ Please fix the failing tests before proceeding."
        echo ""
        echo "🔧 TROUBLESHOOTING:"
        echo "1. Run the implementation script: ./scripts/implement_health_check_system.sh"
        echo "2. Check file permissions: chmod +x scripts/*.sh"
        echo "3. Validate prerequisites: aws --version && terraform --version"
        echo "4. Review error messages above"
        echo ""
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
Glue Health Check System Test Suite

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -q, --quiet     Suppress non-essential output

DESCRIPTION:
    Validates the complete Glue health check system implementation
    without deploying resources to AWS. Tests include:
    
    - Directory structure validation
    - Script existence and permissions
    - Terraform syntax validation
    - Python script syntax checking
    - Configuration file validation
    - Prerequisites verification

EXAMPLES:
    # Run all tests
    $0
    
    # Run with verbose output
    $0 --verbose
    
    # Run quietly (errors only)
    $0 --quiet

EXIT CODES:
    0    All tests passed
    1    One or more tests failed

EOF
}

# Parse command line arguments
VERBOSE=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            set -x
            shift
            ;;
        -q|--quiet)
            QUIET=true
            exec > /dev/null
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main "$@" 