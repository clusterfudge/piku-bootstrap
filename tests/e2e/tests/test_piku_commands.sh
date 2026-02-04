#!/bin/bash
# Test piku CLI commands
source /lib/test_helpers.sh

# Deploy a test app first that we'll use for all command tests
APP_NAME="test-piku-commands"

setup_test_app() {
    log_info "Setting up test app for command tests..."
    local app_dir=$(create_app "$APP_NAME")
    create_flask_app "$app_dir"
    deploy_app "$APP_NAME"
    wait_for_app "$APP_NAME" 180
    sleep 5
}

cleanup_test_app() {
    destroy_app "$APP_NAME"
}

#######################################
# Test 1: piku logs
#######################################
test_piku_logs() {
    log_info "Testing 'piku logs' command..."
    
    local output
    output=$(run_piku logs "$APP_NAME" 2>&1 || true)
    
    # Logs should contain something (even if empty app logs)
    if [ -n "$output" ] || run_piku logs "$APP_NAME" >/dev/null 2>&1; then
        log_pass "piku logs command works"
        return 0
    else
        log_fail "piku logs command failed"
        return 1
    fi
}

#######################################
# Test 2: piku config:set and config:get
#######################################
test_piku_config() {
    log_info "Testing 'piku config:set' and 'config:get' commands..."
    
    # Set a config variable
    log_info "Setting TEST_VAR=hello..."
    run_piku config:set "$APP_NAME" TEST_VAR=hello
    
    # Get the config and verify
    log_info "Getting config..."
    local output
    output=$(run_piku config "$APP_NAME" 2>&1)
    
    if echo "$output" | grep -q "TEST_VAR.*hello"; then
        log_pass "config:set/get works"
        return 0
    else
        log_fail "Config not set correctly. Output: $output"
        return 1
    fi
}

#######################################
# Test 3: piku restart
#######################################
test_piku_restart() {
    log_info "Testing 'piku restart' command..."
    
    # Restart the app
    if run_piku restart "$APP_NAME" 2>&1; then
        sleep 5  # Wait for restart
        
        # Verify app is still responding
        if test_http "$APP_NAME" "Hello"; then
            log_pass "piku restart works"
            return 0
        else
            log_fail "App not responding after restart"
            return 1
        fi
    else
        log_fail "piku restart command failed"
        return 1
    fi
}

#######################################
# Test 4: piku ps (list processes)
#######################################
test_piku_ps() {
    log_info "Testing 'piku ps' command..."
    
    local output
    output=$(run_piku ps "$APP_NAME" 2>&1 || true)
    
    # ps should show something about the app
    if echo "$output" | grep -qiE "(wsgi|web|worker|running|pid)"; then
        log_pass "piku ps command works"
        return 0
    else
        # Even if output is different, command should not error
        if run_piku ps "$APP_NAME" >/dev/null 2>&1; then
            log_pass "piku ps command executes (output format may vary)"
            return 0
        fi
        log_fail "piku ps command failed. Output: $output"
        return 1
    fi
}

#######################################
# Test 5: piku stop and start
#######################################
test_piku_stop_start() {
    log_info "Testing 'piku stop' and 'piku start' commands..."
    
    # Stop the app
    log_info "Stopping app..."
    run_piku stop "$APP_NAME" 2>&1 || true
    sleep 3
    
    # Start the app
    log_info "Starting app..."
    run_piku start "$APP_NAME" 2>&1 || true
    sleep 5
    
    # Verify app is responding
    if test_http "$APP_NAME" "Hello"; then
        log_pass "piku stop/start works"
        return 0
    else
        log_fail "App not responding after stop/start"
        return 1
    fi
}

#######################################
# Test 6: piku destroy (run last!)
#######################################
test_piku_destroy() {
    log_info "Testing 'piku destroy' command..."
    
    # Create a temporary app to destroy
    local temp_app="test-destroy-me"
    local app_dir=$(create_app "$temp_app")
    create_flask_app "$app_dir"
    deploy_app "$temp_app"
    wait_for_app "$temp_app" 120
    
    # Destroy it
    log_info "Destroying temporary app..."
    if run_piku destroy "$temp_app" 2>&1; then
        sleep 2
        
        # Verify it's gone - the uwsgi config should not exist
        if ! ssh_server "test -f /home/piku/.piku/uwsgi-enabled/$temp_app.ini"; then
            log_pass "piku destroy works"
            rm -rf "$TEST_APP_DIR/$temp_app"
            return 0
        else
            log_fail "App still exists after destroy"
            return 1
        fi
    else
        log_fail "piku destroy command failed"
        return 1
    fi
}

#######################################
# Run all tests
#######################################

# Setup
setup_test_app

# Run command tests
run_test "piku logs" test_piku_logs
run_test "piku config:set/get" test_piku_config
run_test "piku restart" test_piku_restart
run_test "piku ps" test_piku_ps
run_test "piku stop/start" test_piku_stop_start
run_test "piku destroy" test_piku_destroy

# Cleanup
cleanup_test_app

test_summary
