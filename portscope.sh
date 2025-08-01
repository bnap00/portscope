#!/bin/bash

# Define the version of the script
VERSION="1.2.2"

# Whether to auto-confirm prompts
AUTO_YES=0
if [[ ${PORTSCOPE_YES:-0} == 1 || ${CI:-} == true ]]; then
    AUTO_YES=1
fi

# Check arguments for --yes flag
for arg in "$@"; do
    if [[ $arg == "--yes" ]]; then
        AUTO_YES=1
        break
    fi
done

# Remove leading --yes if present
if [[ $1 == "--yes" ]]; then
    shift
fi

# Function to display help message
show_help() {
    cat <<EOF
Usage: portscope [DIRECTORY|FILE]

Check if ports defined in a docker-compose.yml file are already in use.

Options:
  --help        Show this help message
  --version     Show version information
  --free-port N Attempt to free port N if it is in use
  --yes         Assume "yes" for all prompts
EOF
}

# Function to display version information
show_version() {
    echo "portscope version $VERSION"
}

# Prompt for confirmation unless AUTO_YES is set
prompt_confirm() {
    local msg="$1"
    if [[ $AUTO_YES -eq 1 ]]; then
        return 0
    fi
    read -rp "$msg [y/N] " ans
    [[ $ans =~ ^[Yy]$ ]]
}

# Function to attempt freeing a port
free_port() {
    local port="$1"

    if [[ -z "$port" || ! "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Please provide a valid port number." >&2
        return 1
    fi
    if (( port < 1 || port > 65535 )); then
        echo "Error: Port number must be between 1 and 65535." >&2
        return 1
    fi

    # Check if the port is used by a Docker container (if Docker is installed)
    local container_info=""
    if command -v docker >/dev/null 2>&1; then
        container_info=$(docker ps --filter "publish=${port}" --format '{{.ID}} {{.Names}} {{.Label "com.docker.compose.project"}}')
    fi

    if [[ -n "$container_info" ]]; then
        while read -r cid cname cproj; do
            [[ -z $cid ]] && continue
            echo "Port $port is used by Docker container '$cname' (project: ${cproj:-n/a})"
            if prompt_confirm "Stop this container to free the port?"; then
                if docker stop "$cid" >/dev/null; then
                    echo "Container '$cname' stopped."
                else
                    echo "Failed to stop container '$cname'." >&2
                fi
            else
                echo "Port $port left in use by Docker container '$cname'."
            fi
        done <<< "$container_info"
        return 0
    fi

    # Check if the port is used by a regular process
    local pids
    pids=$(ss -ltnp 2>/dev/null | awk -v p=":$port" '$4 ~ p {print $6}' | grep -oE '[0-9]+' | sort -u)
    if [[ -n "$pids" ]]; then
        for pid in $pids; do
            local cmd
            cmd=$(ps -p "$pid" -o cmd --no-headers 2>/dev/null)
            echo "Port $port is used by process $pid ($cmd)"
            if prompt_confirm "Kill this process to free the port?"; then
                if kill "$pid" >/dev/null 2>&1; then
                    echo "Process $pid terminated."
                else
                    echo "Failed to kill process $pid." >&2
                fi
            else
                echo "Port $port left in use by process $pid."
            fi
        done
        return 0
    fi

    echo "Port $port is not currently in use."
}

# Function to check if required commands are available
check_requirements() {
    local missing=0

    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "Error: Required command not found: $cmd" >&2
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        echo "Please install the missing dependencies and try again." >&2
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
    # shellcheck disable=SC2016
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


# Determine operation based on first argument
case "$1" in
    --help)
        show_help
        exit 0
        ;;
    --version)
        show_version
        exit 0
        ;;
    --free-port)
        shift
        check_requirements ss awk grep ps kill
        free_port "$1"
        exit $?
        ;;
    *)
        check_requirements docker ss awk grep sed realpath
        check_ports "$1"
        ;;
esac
