#!/bin/bash

# Azure Zero Trust Segmentation Research - Quick Start Script
# This script helps you deploy the baseline environment

set -e

echo "=================================================="
echo "Azure Zero Trust Segmentation Research"
echo "Quick Start Deployment Script"
echo "=================================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "ERROR: Azure CLI not found. Please install it first."
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo "ERROR: Terraform not found. Please install it first."
    echo "Visit: https://www.terraform.io/downloads"
    exit 1
fi

echo "✓ Azure CLI found: $(az version --query '"azure-cli"' -o tsv)"
echo "✓ Terraform found: $(terraform version | head -n 1)"
echo ""

# Check Azure login
echo "Checking Azure login..."
if ! az account show &> /dev/null; then
    echo "ERROR: Not logged into Azure. Please run: az login"
    exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "✓ Logged into Azure"
echo "  Subscription: $SUBSCRIPTION_NAME"
echo "  ID: $SUBSCRIPTION_ID"
echo ""

# Confirm deployment
read -p "Deploy BASELINE environment? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy baseline
echo ""
echo "=================================================="
echo "Deploying Baseline Configuration"
echo "=================================================="
echo ""

cd baseline

echo "Initializing Terraform..."
terraform init

echo ""
echo "Creating deployment plan..."
terraform plan -out=tfplan

echo ""
read -p "Review the plan above. Continue with deployment? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Deploying infrastructure..."
terraform apply tfplan

echo ""
echo "Saving outputs..."
terraform output > ../baseline-outputs.txt

echo ""
echo "=================================================="
echo "Deployment Complete!"
echo "=================================================="
echo ""