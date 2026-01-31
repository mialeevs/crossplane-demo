#!/bin/bash

set -e

echo "========================================="
echo "Destroying Serverless Order System"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}⚠️  WARNING: This will destroy all resources!${NC}"
echo ""
read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

# Get ECR repository to clean images
echo -e "${YELLOW}Cleaning ECR images...${NC}"
ECR_REPO=$(terraform output -raw ecr_repository_url 2>/dev/null | cut -d'/' -f2 || echo "")
AWS_REGION=$(terraform output -json 2>/dev/null | jq -r '.aws_region.value // "us-east-1"')

if [ ! -z "$ECR_REPO" ]; then
    echo "Deleting images from $ECR_REPO..."
    aws ecr batch-delete-image \
        --repository-name $ECR_REPO \
        --image-ids "$(aws ecr list-images --repository-name $ECR_REPO --region $AWS_REGION --query 'imageIds[*]' --output json)" \
        --region $AWS_REGION 2>/dev/null || true
    echo -e "${GREEN}✓ ECR images deleted${NC}"
fi

# Destroy infrastructure
echo ""
echo -e "${RED}Destroying infrastructure...${NC}"
terraform destroy -auto-approve

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}All resources have been destroyed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Clean up local files
rm -f tfplan
rm -f ../deployment-info.txt
rm -f ../lambda/lambda_function.zip

echo -e "${GREEN}Local cleanup complete.${NC}"
