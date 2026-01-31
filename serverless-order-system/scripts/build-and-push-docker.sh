#!/bin/bash

set -e

echo "========================================="
echo "Building and Pushing Docker Image"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Navigate to terraform directory to get outputs
cd "$(dirname "$0")/../terraform"

# Get ECR repository URL
echo -e "${BLUE}Getting ECR repository URL...${NC}"
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null)
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null)
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null)
AWS_REGION=$(terraform output -json | jq -r '.aws_region.value // "us-east-1"')

if [ -z "$ECR_URL" ]; then
    echo -e "${RED}❌ Could not get ECR repository URL${NC}"
    echo "Please deploy the infrastructure first with ./scripts/deploy.sh"
    exit 1
fi

echo -e "${GREEN}✓ ECR URL: $ECR_URL${NC}"
echo ""

# Extract registry URL (everything before the repository name)
REGISTRY_URL=$(echo $ECR_URL | cut -d'/' -f1)

# Login to ECR
echo -e "${BLUE}Logging in to ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | \
    docker login --username AWS --password-stdin $REGISTRY_URL

echo -e "${GREEN}✓ Logged in to ECR${NC}"
echo ""

# Navigate to docker directory
cd ../docker

# Build Docker image
echo -e "${BLUE}Building Docker image...${NC}"
docker build -t order-worker:latest .
echo -e "${GREEN}✓ Docker image built${NC}"
echo ""

# Tag the image
echo -e "${BLUE}Tagging image...${NC}"
docker tag order-worker:latest $ECR_URL:latest
docker tag order-worker:latest $ECR_URL:$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Image tagged${NC}"
echo ""

# Push to ECR
echo -e "${BLUE}Pushing image to ECR...${NC}"
docker push $ECR_URL:latest
docker push $ECR_URL:$(date +%Y%m%d-%H%M%S)
echo -e "${GREEN}✓ Image pushed to ECR${NC}"
echo ""

# Update ECS service
echo -e "${BLUE}Updating ECS service...${NC}"
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $AWS_REGION \
    > /dev/null

echo -e "${GREEN}✓ ECS service updated${NC}"
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Docker Image Deployed Successfully!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}📦 Image:${NC} $ECR_URL:latest"
echo ""
echo -e "${BLUE}🔍 Monitor ECS deployment:${NC}"
echo "   aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $AWS_REGION"
echo ""
echo -e "${BLUE}📊 View ECS logs:${NC}"
echo "   aws logs tail /ecs/serverless-order-system-order-worker-dev --follow --region $AWS_REGION"
echo ""
