# Quick Start Guide

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured (`aws configure`)
3. **Terraform** >= 1.0 installed
4. **Docker** installed and running
5. **Git** (optional)

## 5-Minute Setup

### Step 1: Configure

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and change:
```hcl
admin_email = "YOUR-EMAIL@example.com"  # ← Change this!
```

### Step 2: Deploy Infrastructure

```bash
cd ..
chmod +x scripts/*.sh
./scripts/deploy.sh
```

This will:
- ✅ Create Lambda function
- ✅ Create API Gateway
- ✅ Create EventBridge rules
- ✅ Create SNS topic
- ✅ Create SQS queue
- ✅ Create ECS cluster
- ✅ Create ECR repository
- ✅ Create VPC and networking

### Step 3: Confirm SNS Subscription

Check your email and click the confirmation link for SNS notifications.

### Step 4: Build and Deploy Docker Worker

```bash
./scripts/build-and-push-docker.sh
```

This will:
- ✅ Build Docker image
- ✅ Push to ECR
- ✅ Update ECS service

### Step 5: Test!

Get your API endpoint from the deployment output, then:

```bash
# Replace with your actual API endpoint
export API_URL="https://YOUR-ID.execute-api.us-east-1.amazonaws.com/orders"

# Test with low-value order
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-001",
    "customer_id": "CUST-123",
    "amount": 500
  }'

# Test with high-value order (will be queued)
curl -X POST $API_URL \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-002",
    "customer_id": "CUST-456",
    "amount": 2500
  }'
```

### Step 6: Monitor

**Lambda Logs:**
```bash
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --follow
```

**ECS Worker Logs:**
```bash
aws logs tail /ecs/serverless-order-system-order-worker-dev --follow
```

**SQS Queue:**
```bash
# Get queue URL from terraform output
QUEUE_URL=$(cd terraform && terraform output -raw sqs_queue_url)

# Check messages
aws sqs receive-message --queue-url $QUEUE_URL
```

## Testing with VSCode

1. Install **REST Client** extension
2. Open `tests/api-tests.http`
3. Update `@baseUrl` with your API endpoint
4. Click "Send Request" above any test

## What to Expect

### Low-Value Order (< $1000):
- ✅ Lambda processes request
- ✅ EventBridge receives event
- ✅ SNS sends email notification
- ❌ NOT queued in SQS

### High-Value Order (≥ $1000):
- ✅ Lambda processes request
- ✅ EventBridge receives event
- ✅ SNS sends email notification
- ✅ Queued in SQS
- ✅ ECS worker processes from queue

## Architecture Flow

```
Client
  │
  └─→ API Gateway
        │
        └─→ Lambda Function
              │
              └─→ EventBridge
                    ├─→ SNS (all orders)
                    │     └─→ Email
                    │
                    └─→ SQS (high-value orders only)
                          └─→ ECS Worker (Fargate)
```

## Cleanup

To destroy all resources:

```bash
./scripts/destroy.sh
```

⚠️ **Warning:** This permanently deletes everything!

## Troubleshooting

### Issue: No email notifications
**Solution:** Check SNS subscription status:
```bash
aws sns list-subscriptions
```

### Issue: ECS task not running
**Solution:** Check service status:
```bash
aws ecs describe-services \
  --cluster serverless-order-system-dev-cluster \
  --services serverless-order-system-dev-order-worker-service
```

### Issue: Lambda errors
**Solution:** Check logs:
```bash
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --follow
```

## Cost Estimation

Running 24/7 with moderate usage (~10,000 requests/month):
- **API Gateway:** ~$0.35
- **Lambda:** ~$0.20
- **EventBridge:** ~$0.10
- **SNS:** ~$0.50
- **SQS:** ~$0.40
- **ECS Fargate (1 task):** ~$15
- **CloudWatch Logs:** ~$0.50

**Total:** ~$17/month

💡 **Tip:** Scale ECS to 0 when not testing to save ~$15/month:
```bash
aws ecs update-service \
  --cluster serverless-order-system-dev-cluster \
  --service serverless-order-system-dev-order-worker-service \
  --desired-count 0
```

## Next Steps

1. **Add authentication** to API Gateway
2. **Enable auto-scaling** for ECS
3. **Set up CloudWatch alarms**
4. **Implement DLQ handling**
5. **Add CI/CD pipeline**

## Support

For issues:
1. Check CloudWatch logs
2. Verify IAM permissions
3. Review Terraform state
4. Check AWS service quotas

---

**Happy Building! 🚀**
