import json
import boto3
import os
from botocore.exceptions import ClientError

s3 = boto3.client('s3')
sns = boto3.client('sns')

# S3 and SNS configuration from environment variables
bucket_name = os.environ.get('BUCKET_NAME')
events_file_key = 'events.json'
sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')

def lambda_handler(event, context):
    try:
        new_event = json.loads(event['body'])  # Parse event body
        
        # Fetch existing events
        response = s3.get_object(Bucket=bucket_name, Key=events_file_key)
        events_data = json.loads(response['Body'].read().decode('utf-8'))
        
        # Add the new event
        events_data.append(new_event)
        
        # Update events.json in S3
        s3.put_object(
            Bucket=bucket_name,
            Key=events_file_key,
            Body=json.dumps(events_data, indent=2),
            ContentType='application/json'
        )
        
        # Send SNS notification
        message = f"New Event: {new_event['title']} on {new_event['date']}\n{new_event['description']}"
        sns.publish(TopicArn=sns_topic_arn, Message=message, Subject="New Event Announcement")
        
        return {
            'statusCode': 200,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            'body': json.dumps({'message': 'Event created successfully!'})
        }
        
    except ClientError as e:
        print(f"Error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            'body': json.dumps({'message': 'Error processing the event'})
        }
        
    except Exception as e:
        print(f"Unexpected Error: {e}")
        return {
            'statusCode': 500,
            'headers': {
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS, POST",
                "Access-Control-Allow-Headers": "Content-Type"
            },
            'body': json.dumps({'message': 'Unexpected error occurred'})
        }
