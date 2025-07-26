#!/bin/bash

# portscope - check for host port conflicts in docker-compose files

check_ports() {
    local target="$1"
    local compose_file=""

    # Step 1: Determine target
    if [[ -z "$target" ]]; then
        target="."
    fi

    if [[ -d "$target" ]]; then
        # Target is a directory
        if [[ -f "$target/docker-compose.yml" ]]; then
            compose_file="$target/docker-compose.yml"
        else
            echo "Error: docker-compose.yml not found in $target"
            return 1
        fi
    elif [[ -f "$target" ]]; then
        # Target is a file
        if [[ "$(basename "$target")" == "docker-compose.yml" ]]; then
            compose_file="$target"
        else
            # If file is not docker-compose.yml, try parsing as compose file
            compose_file="$target"
        fi
    else
        echo "Error: Target not found: $target"
        return 1
    fi

    # Step 2: Validate it's a YAML file
    if [[ "$compose_file" != *.yml && "$compose_file" != *.yaml ]]; then
        echo "Error: File is not a YAML: $compose_file"
        return 1
    fi

    echo "Using docker-compose file: $compose_file"

    # Step 3: Extract host ports
    local ports
    ports=$(grep -E '^\s*-\s*"?[0-9]+:' "$compose_file" | sed -E 's/.*- "?([0-9]+):.*/\1/' | sort -n | uniq)

    if [[ -z "$ports" ]]; then
        echo "No host ports found in $compose_file"
        return 0
    fi

    echo "Required host ports: $ports"

    # Step 4: Get all currently used ports
    local used_ports
    used_ports=$(ss -tuln | awk 'NR>1 {split($5,a,":"); print a[length(a)]}' | sort -n | uniq)

    # Step 5: Check conflicts
    local conflict=0
    for p in $ports; do
        if echo "$used_ports" | grep -q "^$p$"; then
            echo "Conflict: Port $p is already in use"
            conflict=1
        fi
    done

    if [[ $conflict -eq 0 ]]; then
        echo "All good: No port conflicts detected."
    fi
}

check_ports "$1"
