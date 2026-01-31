import boto3
import json
import time
import os
import sys
from datetime import datetime

# Initialize SQS client
sqs = boto3.client('sqs')

# Environment variables
QUEUE_URL = os.environ.get('QUEUE_URL')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')
POLL_INTERVAL = int(os.environ.get('POLL_INTERVAL', '20'))  # seconds


def process_order(order_data):
    """
    Process a high-value order
    This is where you would implement your business logic
    """
    try:
        order_id = order_data.get('orderId', 'UNKNOWN')
        amount = order_data.get('amount', 0)
        customer_id = order_data.get('customerId', 'UNKNOWN')
        
        print(f"[{datetime.utcnow().isoformat()}] Processing high-value order:")
        print(f"  Order ID: {order_id}")
        print(f"  Customer ID: {customer_id}")
        print(f"  Amount: ${amount}")
        print(f"  Environment: {ENVIRONMENT}")
        
        # Simulate complex processing
        # In a real application, this might include:
        # - Fraud detection
        # - Credit check
        # - Inventory verification
        # - Payment processing
        # - Customer notification
        # - Database updates
        
        print(f"  Starting fraud detection...")
        time.sleep(2)
        print(f"  ✓ Fraud check passed")
        
        print(f"  Verifying inventory...")
        time.sleep(1)
        print(f"  ✓ Inventory verified")
        
        print(f"  Processing payment...")
        time.sleep(2)
        print(f"  ✓ Payment processed")
        
        print(f"✅ Order {order_id} processed successfully!")
        return True
        
    except Exception as e:
        print(f"❌ Error processing order: {str(e)}")
        return False


def parse_message_body(message_body):
    """
    Parse message body which might be wrapped by EventBridge
    """
    try:
        # Try to parse as JSON
        body = json.loads(message_body)
        
        # Check if it's an EventBridge event
        if 'detail' in body:
            # EventBridge wraps the actual data in a 'detail' field
            return body['detail']
        else:
            # Direct SQS message
            return body
            
    except json.JSONDecodeError as e:
        print(f"Failed to parse message body: {str(e)}")
        return None


def main():
    """
    Main worker loop - polls SQS and processes messages
    """
    if not QUEUE_URL:
        print("❌ ERROR: QUEUE_URL environment variable not set!")
        sys.exit(1)
    
    print("=" * 60)
    print(f"🚀 Order Processing Worker Starting")
    print(f"   Queue URL: {QUEUE_URL}")
    print(f"   Region: {AWS_REGION}")
    print(f"   Environment: {ENVIRONMENT}")
    print(f"   Poll Interval: {POLL_INTERVAL}s")
    print("=" * 60)
    
    while True:
        try:
            print(f"\n[{datetime.utcnow().isoformat()}] Polling for messages...")
            
            # Receive messages from SQS
            response = sqs.receive_message(
                QueueUrl=QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=POLL_INTERVAL,  # Long polling
                VisibilityTimeout=300  # 5 minutes to process
            )
            
            # Check if we received any messages
            if 'Messages' not in response:
                print("  No messages received")
                continue
            
            # Process each message
            for message in response['Messages']:
                message_id = message['MessageId']
                receipt_handle = message['ReceiptHandle']
                
                print(f"\n📬 Received message: {message_id}")
                
                # Parse message body
                order_data = parse_message_body(message['Body'])
                
                if order_data is None:
                    print(f"⚠️  Failed to parse message, skipping...")
                    # Delete the message to prevent reprocessing
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    continue
                
                # Process the order
                success = process_order(order_data)
                
                if success:
                    # Delete the message from the queue
                    sqs.delete_message(
                        QueueUrl=QUEUE_URL,
                        ReceiptHandle=receipt_handle
                    )
                    print(f"✅ Message {message_id} deleted from queue")
                else:
                    print(f"⚠️  Processing failed for message {message_id}")
                    print(f"   Message will become visible again after timeout")
                    # Message will automatically become visible again
                    # After max retries, it will go to DLQ
        
        except KeyboardInterrupt:
            print("\n\n👋 Shutting down worker...")
            break
            
        except Exception as e:
            print(f"\n❌ Error in main loop: {str(e)}")
            print(f"   Waiting 10 seconds before retry...")
            time.sleep(10)


if __name__ == "__main__":
    main()
