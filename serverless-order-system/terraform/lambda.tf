# Lambda Function Configuration

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/lambda_function.py"
  output_path = "${path.module}/../lambda/lambda_function.zip"
}

resource "aws_lambda_function" "order_processor" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${local.name_prefix}-order-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "python3.12"
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      EVENTBRIDGE_BUS_NAME = "default"
      SNS_TOPIC_ARN       = aws_sns_topic.order_notifications.arn
      ENVIRONMENT         = var.environment
      PROJECT_NAME        = var.project_name
    }
  }

  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.lambda_logs.name
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-order-processor"
    }
  )
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.name_prefix}-order-processor"
  retention_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-lambda-logs"
    }
  )
}
