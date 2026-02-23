#!/bin/bash
# Test Python UV deployments with pyproject.toml
# Migrated from original test_uv_e2e.sh
#
# NOTE: These tests use the SYSTEM Python version (not pinned versions)
# because piku's uwsgi-plugin-python3 is compiled against the system
# Python. Pinning a different version (e.g., 3.10 on a 3.13 system)
# would cause ABI mismatches between the uv-managed virtualenv and
# the uwsgi plugin.
source /test-lib/test_helpers.sh

# Get system Python major.minor version for use in tests
SYSTEM_PYTHON_VERSION=$(ssh_server "python3 -c 'import sys; print(f\"{sys.version_info.major}.{sys.version_info.minor}\")'")
log_info "System Python version: ${SYSTEM_PYTHON_VERSION}"

#######################################
# Test 1: Basic UV deployment
#######################################
test_basic_uv() {
    local app_name="test-uv-basic"
    
    log_info "Creating basic UV Flask app..."
    local app_dir=$(create_app "$app_name")
    # Use system python version to match uwsgi plugin
    create_uv_flask_app "$app_dir" "${SYSTEM_PYTHON_VERSION}"
    
    log_info "Deploying app..."
    deploy_app "$app_name"
    
    log_info "Waiting for app to be ready..."
    wait_for_app "$app_name" 180
    sleep 5
    
    log_info "Testing HTTP response..."
    test_http "$app_name" "Hello from UV Flask"
    
    local result=$?
    destroy_app "$app_name"
    return $result
}

#######################################
# Test 2: Multiple dependencies
#######################################
test_uv_multiple_deps() {
    local app_name="test-uv-deps"
    
    log_info "Creating UV app with multiple dependencies..."
    local app_dir=$(create_app "$app_name")
    
    cat > "$app_dir/pyproject.toml" << EOF
[project]
name = "test-app"
version = "0.1.0"
requires-python = ">=${SYSTEM_PYTHON_VERSION}"
dependencies = [
    "flask",
    "requests",
    "click",
]
EOF

    cat > "$app_dir/wsgi.py" << 'EOF'
from flask import Flask
import requests
import click
app = Flask(__name__)

@app.route('/')
def hello():
    return f'UV deps: requests={requests.__version__}, click={click.__version__}'

application = app
EOF

    cat > "$app_dir/Procfile" << 'EOF'
wsgi: wsgi:app
EOF

    cat > "$app_dir/ENV" << EOF
NGINX_SERVER_NAME=$app_name
EOF
    
    log_info "Deploying app..."
    deploy_app "$app_name"
    wait_for_app "$app_name" 180
    sleep 5
    
    log_info "Testing HTTP response..."
    test_http "$app_name" "requests="
    
    local result=$?
    destroy_app "$app_name"
    return $result
}

#######################################
# Run all tests
#######################################
run_test "Basic UV deployment" test_basic_uv
run_test "Multiple UV dependencies" test_uv_multiple_deps

test_summary
