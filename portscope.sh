#!/bin/bash

# Define the version of the script
VERSION="1.1.0"

# Function to display help message
show_help() {
    cat <<EOF
Usage: portscope [DIRECTORY|FILE]

Check if ports defined in a docker-compose.yml file are already in use.

Options:
  --help        Show this help message
  --version     Show version information
EOF
}

# Function to display version information
show_version() {
    echo "portscope version $VERSION"
}

# Function to check if required commands are available
check_requirements() {
    local missing=0

    # List of required commands
    for cmd in docker ss awk grep sed realpath; do
        if ! command -v "$cmd" > /dev/null; then
            echo "Error: Required command not found: $cmd"
            missing=1
        fi
    done

    # Exit if any required command is missing
    if [[ $missing -eq 1 ]]; then
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Function to check for port conflicts in a docker-compose file
check_ports() {
    local target="$1"
    local compose_file=""

    # Default to current directory if no target is provided
    if [[ -z "$target" ]]; then
        target="."
    fi

    # Handle special options
    if [[ "$target" == "--help" ]]; then
        show_help
        return 0
    elif [[ "$target" == "--version" ]]; then
        show_version
        return 0
    fi

    # Determine the docker-compose file based on the target
    if [[ -d "$target" ]]; then
        if [[ -f "$target/docker-compose.yml" ]]; then
            compose_file="$target/docker-compose.yml"
        else
            echo "Error: docker-compose.yml not found in $target"
            return 1
        fi
    elif [[ -f "$target" ]]; then
        compose_file="$target"
    else
        echo "Error: Target not found: $target"
        return 1
    fi

    # Ensure the file is a valid YAML file
    if [[ "$compose_file" != *.yml && "$compose_file" != *.yaml ]]; then
        echo "Error: File is not a YAML: $compose_file"
        return 1
    fi

    echo "Using docker-compose file: $compose_file"

    # Extract host ports from the docker-compose file
    local ports
    ports=$(grep -E '^\s*-\s*"?[0-9]+:' "$compose_file" | sed -E 's/.*- "?([0-9]+):.*/\1/' | sort -n | uniq)

    # Check if any ports are defined
    if [[ -z "$ports" ]]; then
        echo "No host ports found in $compose_file"
        return 0
    fi

    echo "Required host ports: $ports"

    # Get currently used ports and their associated projects
    local used_ports_info
    used_ports_info=$(docker ps -q | xargs docker inspect --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }} {{range $k, $v := .NetworkSettings.Ports}}{{if $v}}{{(index $v 0).HostPort}} {{end}}{{end}}')

    # Get the absolute path of the current directory
    local current_dir
    current_dir=$(realpath "$(dirname "$compose_file")")
    local conflict=0

    # Check for port conflicts
    for port in $ports; do
        found=0
        while IFS= read -r line; do
            container_dir=$(echo "$line" | awk '{print $1}')
            container_ports=$(echo "$line" | cut -d' ' -f2-)
            for cp in $container_ports; do
                if [[ "$cp" == "$port" ]]; then
                    if [[ "$container_dir" == "$current_dir" ]]; then
                        echo "Info: Port $port is already used by the same project – skipping"
                    else
                        echo "Conflict: Port $port is already in use by another container"
                        conflict=1
                    fi
                    found=1
                    break
                fi
            done
            [[ $found -eq 1 ]] && break
        done <<< "$used_ports_info"
    done

    # Report if no conflicts were found
    if [[ $conflict -eq 0 ]]; then
        echo "All good: No external port conflicts detected."
    fi
}

# Check if required commands are installed
check_requirements

# Check ports for the provided target
check_ports "$1"
