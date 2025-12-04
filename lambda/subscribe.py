import json
import boto3
import os

def lambda_handler(event, context):
    # Log the entire event to CloudWatch
    print("Event received:", json.dumps(event))
    
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    
    if 'body' in event:
        body = event['body'] if isinstance(event['body'], dict) else json.loads(event['body'])
        email = body.get('email', None)
        
        if email:
            sns_client = boto3.client('sns')
            
            try:
                # Subscribe the user to the SNS topic (email subscription)
                response = sns_client.subscribe(
                    TopicArn=sns_topic_arn,
                    Protocol='email',
                    Endpoint=email
                )
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({'message': 'Subscription successful! Please check your email to confirm.'})
                }
            
            except Exception as e:
                print(f"Error subscribing user: {str(e)}")
                return {
                    'statusCode': 500,
                    'body': json.dumps({'error': f'Failed to subscribe: {str(e)}'})
                }
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Email not provided.'})
            }
    
    return {
        'statusCode': 400,
        'body': json.dumps({'error': 'Invalid request format.'})
    }
