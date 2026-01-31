output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = "${aws_apigatewayv2_api.orders_api.api_endpoint}/orders"
}

output "api_gateway_id" {
  description = "API Gateway ID"
  value       = aws_apigatewayv2_api.orders_api.id
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.order_processor.function_name
}

output "lambda_log_group" {
  description = "Lambda CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.order_worker.repository_url
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.order_processing_queue.url
}

output "sqs_queue_arn" {
  description = "SQS queue ARN"
  value       = aws_sqs_queue.order_processing_queue.arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN"
  value       = aws_sns_topic.order_notifications.arn
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.order_worker.name
}

output "ecs_log_group" {
  description = "ECS CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value       = <<-EOT
  
  ✅ Deployment Complete!
  
  📡 API Endpoint: ${aws_apigatewayv2_api.orders_api.api_endpoint}/orders
  
  📧 SNS Topic: Confirm subscription at ${var.admin_email}
  
  🐳 Build and push Docker image:
     cd ../
     ./scripts/build-and-push-docker.sh
  
  🧪 Test your API:
     curl -X POST ${aws_apigatewayv2_api.orders_api.api_endpoint}/orders \
       -H "Content-Type: application/json" \
       -d '{"order_id": "ORD-001", "customer_id": "CUST-123", "amount": 1500}'
  
  📊 Monitor logs:
     aws logs tail ${aws_cloudwatch_log_group.lambda_logs.name} --follow
  
  EOT
}
