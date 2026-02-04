#!/bin/bash
# E2E Test Runner for piku-bootstrap
# Orchestrates multi-container tests using Docker Compose

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
COMPOSE_PROJECT="piku-e2e-tests"
KEEP_CONTAINERS=false
NO_BUILD=false
TEST_FILTER=""
PIKU_REPO="${PIKU_REPO:-piku/piku}"
PIKU_BRANCH="${PIKU_BRANCH:-master}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [TEST_PATTERN]

Run E2E tests for piku-bootstrap in Docker containers.

OPTIONS:
    -h, --help          Show this help message
    -k, --keep          Keep containers running after tests (for debugging)
    -n, --no-build      Skip Docker image build
    --piku-repo=REPO    GitHub repo to install piku from (default: piku/piku)
    --piku-branch=BRANCH Branch to install from (default: master)

TEST_PATTERN:
    Optional pattern to filter which tests to run (e.g., "python" or "nodejs")

EXAMPLES:
    $0                          # Run all tests
    $0 --keep                   # Run tests, keep containers for debugging
    $0 python                   # Run only Python-related tests
    $0 --piku-repo=myuser/piku  # Test with a fork

DEBUGGING:
    After running with --keep, you can:
    - docker exec -it piku-e2e-tests-test-client-1 bash
    - docker exec -it piku-e2e-tests-piku-server-1 bash
    - docker-compose -p $COMPOSE_PROJECT logs -f
EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    if [ "$KEEP_CONTAINERS" = false ]; then
        log_info "Cleaning up containers..."
        docker-compose -p "$COMPOSE_PROJECT" down -v --remove-orphans 2>/dev/null || true
    else
        log_warn "Containers kept running. Clean up with:"
        echo "  docker-compose -p $COMPOSE_PROJECT down -v"
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -k|--keep)
            KEEP_CONTAINERS=true
            shift
            ;;
        -n|--no-build)
            NO_BUILD=true
            shift
            ;;
        --piku-repo=*)
            PIKU_REPO="${1#*=}"
            shift
            ;;
        --piku-branch=*)
            PIKU_BRANCH="${1#*=}"
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            TEST_FILTER="$1"
            shift
            ;;
    esac
done

# Set up cleanup trap
trap cleanup EXIT

log_info "=== Piku E2E Test Suite ==="
log_info "Piku Repository: $PIKU_REPO"
log_info "Piku Branch: $PIKU_BRANCH"
[ -n "$TEST_FILTER" ] && log_info "Test Filter: $TEST_FILTER"

# Export for docker-compose
export PIKU_REPO
export PIKU_BRANCH
export COMPOSE_PROJECT

# Build images
if [ "$NO_BUILD" = false ]; then
    log_info "Building Docker images..."
    docker-compose -p "$COMPOSE_PROJECT" build
fi

# Start containers
log_info "Starting containers (this may take a few minutes for piku bootstrap)..."
docker-compose -p "$COMPOSE_PROJECT" up -d

# Wait for piku-server to be healthy
log_info "Waiting for piku-server to be ready..."
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if docker-compose -p "$COMPOSE_PROJECT" ps piku-server | grep -q "healthy"; then
        log_info "piku-server is ready!"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo -n "."
done
echo

if [ $ELAPSED -ge $TIMEOUT ]; then
    log_error "Timeout waiting for piku-server"
    docker-compose -p "$COMPOSE_PROJECT" logs piku-server
    exit 1
fi

# Set up SSH on the client
log_info "Setting up SSH keys on test client..."
docker-compose -p "$COMPOSE_PROJECT" exec -T test-client bash -c '
    cp /shared-keys/id_ed25519 /root/.ssh/
    chmod 600 /root/.ssh/id_ed25519
    ssh-keyscan -H piku-server >> /root/.ssh/known_hosts 2>/dev/null
    git config --global user.email "test@piku.test"
    git config --global user.name "Piku Test"
'

# Find and run tests
log_info "Running tests..."
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=""

if [ -n "$TEST_FILTER" ]; then
    TEST_FILES=$(find tests -name "test_*.sh" | grep -i "$TEST_FILTER" || true)
else
    TEST_FILES=$(find tests -name "test_*.sh" 2>/dev/null || true)
fi

if [ -z "$TEST_FILES" ]; then
    log_warn "No test files found"
    exit 0
fi

for test_file in $TEST_FILES; do
    test_name=$(basename "$test_file" .sh)
    log_info "Running: $test_name"
    
    if docker-compose -p "$COMPOSE_PROJECT" exec -T test-client bash -c "
        source /lib/test_helpers.sh
        bash /$test_file
    "; then
        log_info "PASSED: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_error "FAILED: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        FAILED_TESTS="$FAILED_TESTS $test_name"
    fi
done

echo
log_info "=== Test Summary ==="
log_info "Passed: $TESTS_PASSED"
[ $TESTS_FAILED -gt 0 ] && log_error "Failed: $TESTS_FAILED ($FAILED_TESTS)"

exit $TESTS_FAILED
