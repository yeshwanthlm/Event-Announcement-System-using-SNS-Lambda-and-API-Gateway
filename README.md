# Event Announcement System using SNS, Lambda and API Gateway
### Overview of Project ☁️
Develop an event announcement website that allows users to:

* Subscribe to event notifications via email.
* View a list of events.
* Create new events through a form.

1. Upload the HTML, CSS, and events.json files to S3 and enable static hosting to access the website URL.
2. Set up an API Gateway to handle backend processing for creating new events on /create-event and adding subscribers on /subscribe.
3. Subscription Lambda adds new subscriber emails to the SNS topic.
4. Event Registration Lambda updates events.json in S3 with new event details submitted from the website form and sends notifications via SNS.

### Services Used 🛠
1. AWS S3: Host the frontend and store event data in a JSON file.[Frontend Hosting & Storage]
2. AWS SNS: Manage email subscriptions and send event notifications.[Notifications]
3. AWS Lambda: Handle backend logic for creating events and managing subscriptions.[Backend Processing]
4. AWS API Gateway: Provide endpoints for frontend to communicate with backend services.[API Management]
5. IAM Roles & Policies: Secure access to AWS resources like S3 and SNS.[Permissions]

### Architecture Diagram ✍️:
<img width="1281" height="540" alt="image" src="https://github.com/user-attachments/assets/aa79d956-f599-46b6-97bf-ee48edd86f6b" />

### Estimated Time & Cost ⚙️
* This project is estimated to take about 2-3 hours
* Cost: Free Tier Eligible

### Steps to be Performed:
1. Set up frontend hosting with S3
2. Integrate SNS Notifications and Lambda Functions
3. Setup, Test and Deploy the API Gateway
4. Test and Finalize

#### 1. Set up frontend hosting with S3

S3 Bucket Policy:
```JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::<YOUR-UNIQUE-BUCKET-NAME>/*"
    }
  ]
}
```
Note: Replace <YOUR-UNIQUE-BUCKET-NAME> with your bucket name.

#### 2. Set up frontend hosting with S3
* Select Standard as the topic type.
* Provide a name for your topic, such as ```sh EventAnnouncements```.
* Create a role for Lambda: LambdaSubscribeRole with ```sh AmazonSNSFullAccess and AWSLambdaBasicExecutionRole```
* Lambda Function Name: ```sh SubscribeToSNSFunction```
* Lambda Funtion:

```python
import json
import boto3

def lambda_handler(event, context):
    # Log the entire event to CloudWatch
    print("Event received:", json.dumps(event))

    if 'body' in event:
      body = event['body'] if isinstance(event['body'], dict) else json.loads(event['body'])
      email = body.get('email', None)

        if email:
            sns_client = boto3.client('sns')

            try:
                # Subscribe the user to the SNS topic (email subscription)
                response = sns_client.subscribe(
                    TopicArn='enter-sns-topic-ARN',  # Replace with your SNS Topic ARN
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
                    'body': json.dumps({'error': f'Failed to subscribe: {str(e)}'}).encode('utf-8')
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


```
Explanation of Code:

* sns_client = boto3.client('sns'): This creates an SNS client to interact with SNS.
* sns_client.subscribe: This subscribes the provided email address to the SNS topic.
* The function checks if the email is present in the request body, and if so, subscribes it to the SNS topic using the provided ARN.


Create a test event ```sh TestSubscribeEvent```

```JSON
{
  "body": {
    "email": "user@example.com"
  }
}

```
