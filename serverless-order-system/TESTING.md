# Testing Guide

This guide provides comprehensive instructions for testing the Serverless Order System.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [API Testing](#api-testing)
3. [Component Testing](#component-testing)
4. [End-to-End Testing](#end-to-end-testing)
5. [Load Testing](#load-testing)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

Before testing, ensure:
- ✅ Infrastructure is deployed
- ✅ Docker image is pushed to ECR
- ✅ SNS subscription is confirmed
- ✅ You have your API endpoint URL

Get your API endpoint:
```bash
cd terraform
terraform output api_gateway_url
```

## API Testing

### Option 1: Using cURL

**Health Check:**
```bash
API_URL="https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com"

curl -X GET $API_URL/health
```

**Create Low-Value Order:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-001",
    "customer_id": "CUST-123",
    "amount": 500
  }'
```

**Create High-Value Order:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ORD-002",
    "customer_id": "CUST-456",
    "amount": 2500
  }'
```

### Option 2: Using VSCode REST Client

1. Install "REST Client" extension
2. Open `tests/api-tests.http`
3. Update `@baseUrl` variable
4. Click "Send Request" above any test

### Option 3: Using Postman

1. Create new request
2. Method: POST
3. URL: `https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/orders`
4. Headers: `Content-Type: application/json`
5. Body (raw JSON):
```json
{
  "order_id": "ORD-003",
  "customer_id": "CUST-789",
  "amount": 1500
}
```

## Component Testing

### 1. Lambda Function Testing

**View Lambda Logs:**
```bash
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --follow
```

**Test Lambda Directly:**
```bash
aws lambda invoke \
  --function-name serverless-order-system-order-processor-dev \
  --payload '{
    "body": "{\"order_id\": \"TEST-001\", \"customer_id\": \"CUST-TEST\", \"amount\": 1500}",
    "requestContext": {"http": {"method": "POST", "path": "/orders"}}
  }' \
  response.json

cat response.json
```

### 2. EventBridge Testing

**Publish Test Event:**
```bash
aws events put-events \
  --entries '[
    {
      "Source": "order.service",
      "DetailType": "OrderCreated",
      "Detail": "{\"orderId\": \"EVB-001\", \"customerId\": \"CUST-TEST\", \"amount\": 2000}"
    }
  ]'
```

**Check Rule Status:**
```bash
# Notification rule
aws events describe-rule \
  --name serverless-order-system-dev-order-notification

# Processing rule
aws events describe-rule \
  --name serverless-order-system-dev-order-processing
```

### 3. SQS Testing

**Get Queue Attributes:**
```bash
QUEUE_URL=$(cd terraform && terraform output -raw sqs_queue_url)

aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names All
```

**Send Test Message:**
```bash
aws sqs send-message \
  --queue-url $QUEUE_URL \
  --message-body '{
    "orderId": "SQS-001",
    "customerId": "CUST-TEST",
    "amount": 3000
  }'
```

**Receive Message:**
```bash
aws sqs receive-message \
  --queue-url $QUEUE_URL \
  --max-number-of-messages 1
```

**Purge Queue (Delete All Messages):**
```bash
aws sqs purge-queue --queue-url $QUEUE_URL
```

### 4. SNS Testing

**Publish Test Message:**
```bash
TOPIC_ARN=$(cd terraform && terraform output -raw sns_topic_arn)

aws sns publish \
  --topic-arn $TOPIC_ARN \
  --message "Test notification from SNS" \
  --subject "Test Order Notification"
```

**List Subscriptions:**
```bash
aws sns list-subscriptions-by-topic --topic-arn $TOPIC_ARN
```

### 5. ECS Testing

**Check Service Status:**
```bash
aws ecs describe-services \
  --cluster serverless-order-system-dev-cluster \
  --services serverless-order-system-dev-order-worker-service
```

**View Running Tasks:**
```bash
aws ecs list-tasks \
  --cluster serverless-order-system-dev-cluster \
  --service-name serverless-order-system-dev-order-worker-service
```

**Check Task Logs:**
```bash
aws logs tail /ecs/serverless-order-system-order-worker-dev --follow
```

**Force New Deployment:**
```bash
aws ecs update-service \
  --cluster serverless-order-system-dev-cluster \
  --service serverless-order-system-dev-order-worker-service \
  --force-new-deployment
```

**Scale Service:**
```bash
# Scale up
aws ecs update-service \
  --cluster serverless-order-system-dev-cluster \
  --service serverless-order-system-dev-order-worker-service \
  --desired-count 2

# Scale down
aws ecs update-service \
  --cluster serverless-order-system-dev-cluster \
  --service serverless-order-system-dev-order-worker-service \
  --desired-count 0
```

## End-to-End Testing

### Test Scenario 1: Standard Order Flow

1. **Send low-value order:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "E2E-001",
    "customer_id": "CUST-E2E",
    "amount": 500
  }'
```

2. **Check Lambda logs:**
```bash
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --since 1m
```

3. **Verify email notification** in your inbox

4. **Verify NOT in SQS queue:**
```bash
aws sqs receive-message --queue-url $QUEUE_URL
# Should return empty
```

### Test Scenario 2: High-Value Order Flow

1. **Send high-value order:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "E2E-002",
    "customer_id": "CUST-E2E",
    "amount": 2500
  }'
```

2. **Check Lambda logs:**
```bash
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --since 1m
```

3. **Verify email notification**

4. **Verify message in SQS:**
```bash
aws sqs receive-message \
  --queue-url $QUEUE_URL \
  --max-number-of-messages 1
```

5. **Check ECS worker logs:**
```bash
aws logs tail /ecs/serverless-order-system-order-worker-dev --since 5m
```

6. **Wait for processing** (~5 seconds simulation)

7. **Verify message deleted from SQS:**
```bash
aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages
```

### Test Scenario 3: Error Handling

**Invalid JSON:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d 'invalid json'
# Expected: 400 Bad Request
```

**Missing Required Field:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ERR-001",
    "amount": 500
  }'
# Expected: 400 Bad Request with error details
```

**Invalid Amount:**
```bash
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ERR-002",
    "customer_id": "CUST-ERR",
    "amount": "not-a-number"
  }'
# Expected: 400 Bad Request
```

## Load Testing

### Simple Load Test with Apache Bench

```bash
# Install Apache Bench (if not installed)
# Ubuntu/Debian: apt-get install apache2-utils
# macOS: brew install httpd

# Test with 100 requests, 10 concurrent
ab -n 100 -c 10 -p payload.json -T application/json $API_URL/orders
```

**payload.json:**
```json
{
  "order_id": "LOAD-TEST",
  "customer_id": "CUST-LOAD",
  "amount": 1500
}
```

### Load Test with Python Script

Create `load_test.py`:
```python
import requests
import concurrent.futures
import time

API_URL = "https://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/orders"

def send_order(order_num):
    payload = {
        "order_id": f"LOAD-{order_num}",
        "customer_id": f"CUST-{order_num}",
        "amount": 1500
    }
    
    start = time.time()
    response = requests.post(API_URL, json=payload)
    duration = time.time() - start
    
    return {
        "status": response.status_code,
        "duration": duration
    }

# Send 100 requests with 10 concurrent workers
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
    futures = [executor.submit(send_order, i) for i in range(100)]
    results = [f.result() for f in concurrent.futures.as_completed(futures)]

# Analyze results
success = sum(1 for r in results if r["status"] == 200)
avg_duration = sum(r["duration"] for r in results) / len(results)

print(f"Success rate: {success}/100")
print(f"Average duration: {avg_duration:.2f}s")
```

## Monitoring During Tests

### Real-Time Monitoring Commands

**Terminal 1 - Lambda Logs:**
```bash
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --follow
```

**Terminal 2 - ECS Logs:**
```bash
aws logs tail /ecs/serverless-order-system-order-worker-dev --follow
```

**Terminal 3 - SQS Queue Depth:**
```bash
watch -n 5 'aws sqs get-queue-attributes \
  --queue-url $QUEUE_URL \
  --attribute-names ApproximateNumberOfMessages \
  --query "Attributes.ApproximateNumberOfMessages"'
```

### CloudWatch Metrics

**View Lambda Metrics:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=serverless-order-system-order-processor-dev \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

## Validation Checklist

After testing, verify:

- [ ] API Gateway responds with 200 for valid requests
- [ ] Lambda logs show successful processing
- [ ] EventBridge events are published
- [ ] SNS emails are received
- [ ] Low-value orders don't appear in SQS
- [ ] High-value orders appear in SQS
- [ ] ECS worker processes messages
- [ ] Messages are deleted from SQS after processing
- [ ] Error handling works correctly
- [ ] No errors in CloudWatch Logs

## Troubleshooting

### Common Issues

**Issue: "Unable to connect"**
```bash
# Check API Gateway exists
aws apigatewayv2 get-apis --query 'Items[?Name==`serverless-order-system-dev-api`]'
```

**Issue: "Internal Server Error (500)"**
```bash
# Check Lambda logs for errors
aws logs tail /aws/lambda/serverless-order-system-order-processor-dev --since 10m
```

**Issue: "No email notifications"**
```bash
# Check SNS subscription status
aws sns list-subscriptions-by-topic --topic-arn $TOPIC_ARN
# Status should be "Confirmed"
```

**Issue: "Messages not being processed"**
```bash
# Check if ECS service is running
aws ecs describe-services \
  --cluster serverless-order-system-dev-cluster \
  --services serverless-order-system-dev-order-worker-service \
  --query 'services[0].desiredCount'

# Check ECS task status
aws ecs list-tasks \
  --cluster serverless-order-system-dev-cluster \
  --service-name serverless-order-system-dev-order-worker-service
```

**Issue: "Messages in DLQ"**
```bash
# Check DLQ for failed messages
DLQ_URL=$(aws sqs list-queues --queue-name-prefix "serverless-order-system-dev-processing-dlq" --query 'QueueUrls[0]' --output text)

aws sqs receive-message \
  --queue-url $DLQ_URL \
  --max-number-of-messages 10
```

## Cleanup After Testing

```bash
# Purge SQS queue
aws sqs purge-queue --queue-url $QUEUE_URL

# Scale ECS to 0 (save costs)
aws ecs update-service \
  --cluster serverless-order-system-dev-cluster \
  --service serverless-order-system-dev-order-worker-service \
  --desired-count 0
```

## Performance Benchmarks

Expected performance with default configuration:

| Metric | Target | Acceptable Range |
|--------|--------|-----------------|
| API Gateway latency | < 100ms | < 200ms |
| Lambda duration | < 500ms | < 1000ms |
| EventBridge delivery | < 1s | < 5s |
| SNS delivery | < 5s | < 30s |
| SQS message processing | < 10s | < 60s |
| End-to-end (high-value) | < 20s | < 90s |

## Next Steps

1. Set up automated tests with CI/CD
2. Implement integration tests
3. Add performance monitoring
4. Create custom CloudWatch dashboards
5. Set up alarms for critical metrics
