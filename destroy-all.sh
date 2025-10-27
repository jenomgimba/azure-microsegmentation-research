#!/bin/bash

# destroy.sh - Destroy Azure resources to stop costs
# Interactive script to destroy specific configs or all

set -e

echo "========================================"
echo "Azure Resource Cleanup"
echo "========================================"
echo ""

# Check what's deployed
configs=("baseline" "config1-nsg" "config2-asg" "config3-firewall")
deployed=()

echo "Checking for deployed configurations..."
echo ""

for config in "${configs[@]}"; do
    if [ -d "$config" ]; then
        # Check if state file exists and has resources
        cd "$config"
        has_resources=false

        if [ -f "terraform.tfstate" ]; then
            # Check if state file has actual resources (not empty state)
            resource_count=$(grep -c '"type":' terraform.tfstate 2>/dev/null || echo "0")
            if [ "$resource_count" -gt 0 ]; then
                has_resources=true
            fi
        fi

        cd ..

        if [ "$has_resources" = true ]; then
            deployed+=("$config")
            echo "  ✓ $config (deployed)"
        else
            echo "  - $config (not deployed)"
        fi
    fi
done

echo ""

# If nothing deployed, exit
if [ ${#deployed[@]} -eq 0 ]; then
    echo "No deployed configurations found."
    exit 0
fi

# Show menu
echo "Select what to destroy:"
echo ""
echo "  0) Destroy ALL (${deployed[@]})"
echo ""

for i in "${!deployed[@]}"; do
    echo "  $((i+1))) ${deployed[$i]}"
done

echo ""
echo "  q) Cancel"
echo ""

read -p "Enter choice: " choice

# Handle choice
if [ "$choice" = "q" ] || [ "$choice" = "Q" ]; then
    echo "Cancelled."
    exit 0
fi

# Destroy all
if [ "$choice" = "0" ]; then
    echo ""
    read -p "Are you sure you want to destroy ALL configurations? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    echo ""
    echo "Destroying all configurations..."
    echo ""

    for config in "${deployed[@]}"; do
        echo "=========================================="
        echo "Destroying: $config"
        echo "=========================================="
        cd "$config"
        terraform destroy -auto-approve
        echo "✓ $config destroyed"
        cd ..
        echo ""
    done

    echo ""
    echo "✓ ALL RESOURCES DESTROYED"
    echo ""

# Destroy specific config
elif [ "$choice" -ge 1 ] && [ "$choice" -le ${#deployed[@]} ]; then
    idx=$((choice-1))
    config="${deployed[$idx]}"

    echo ""
    read -p "Destroy $config? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi

    echo ""
    echo "=========================================="
    echo "Destroying: $config"
    echo "=========================================="
    cd "$config"
    terraform destroy -auto-approve
    echo ""
    echo "✓ $config destroyed"
    echo ""

else
    echo "Invalid choice."
    exit 1
fi

echo "========================================"
echo "Cleanup complete"
echo "========================================"
echo ""