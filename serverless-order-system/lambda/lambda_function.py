import json
import boto3
import os
from datetime import datetime

# Initialize AWS clients
eventbridge = boto3.client('events')
sns = boto3.client('sns')

# Environment variables
EVENTBRIDGE_BUS_NAME = os.environ.get('EVENTBRIDGE_BUS_NAME', 'default')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
PROJECT_NAME = os.environ.get('PROJECT_NAME', 'serverless-order-system')


def lambda_handler(event, context):
    """
    Process incoming orders from API Gateway
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Handle health check
        if event.get('rawPath') == '/health' or event.get('path') == '/health':
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'status': 'healthy',
                    'service': PROJECT_NAME,
                    'environment': ENVIRONMENT,
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Validate required fields
        required_fields = ['order_id', 'customer_id', 'amount']
        missing_fields = [field for field in required_fields if field not in body]
        
        if missing_fields:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Missing required fields',
                    'missing_fields': missing_fields
                })
            }
        
        order_id = body['order_id']
        customer_id = body['customer_id']
        amount = float(body['amount'])
        
        # Additional order details
        order_data = {
            'orderId': order_id,
            'customerId': customer_id,
            'amount': amount,
            'timestamp': datetime.utcnow().isoformat(),
            'environment': ENVIRONMENT
        }
        
        # Add optional fields if present
        optional_fields = ['product_id', 'quantity', 'notes']
        for field in optional_fields:
            if field in body:
                order_data[field] = body[field]
        
        # Publish event to EventBridge
        eventbridge_response = eventbridge.put_events(
            Entries=[{
                'Source': 'order.service',
                'DetailType': 'OrderCreated',
                'Detail': json.dumps(order_data),
                'EventBusName': EVENTBRIDGE_BUS_NAME
            }]
        )
        
        print(f"EventBridge response: {json.dumps(eventbridge_response)}")
        
        # Check if EventBridge publish was successful
        if eventbridge_response['FailedEntryCount'] > 0:
            print(f"EventBridge failed entries: {eventbridge_response['Entries']}")
            raise Exception("Failed to publish event to EventBridge")
        
        # Prepare response
        response_body = {
            'message': 'Order processed successfully',
            'orderId': order_id,
            'amount': amount,
            'status': 'pending',
            'timestamp': order_data['timestamp']
        }
        
        # Add processing info based on amount
        if amount >= 1000:
            response_body['processing'] = 'queued_for_detailed_review'
            response_body['info'] = 'High-value order queued for processing'
        else:
            response_body['processing'] = 'standard'
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(response_body)
        }
        
    except json.JSONDecodeError as e:
        print(f"JSON decode error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid JSON in request body',
                'details': str(e)
            })
        }
        
    except ValueError as e:
        print(f"Value error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Invalid data format',
                'details': str(e)
            })
        }
        
    except Exception as e:
        print(f"Error processing order: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Internal server error',
                'message': 'Failed to process order',
                'details': str(e)
            })
        }
