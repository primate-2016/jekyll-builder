import boto3
import os
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    
    '''
    GitHub webhook will wait for 10 seconds for a
    response, this is not long enough for jekyll-builder
    so invoke the builder async using this function and return
    a 200 to GitHub
    '''
    logger.debug('Received event {}'.format(event))
    
    client = boto3.client('lambda')
    response = client.invoke(
        FunctionName=os.environ['LAMBDA_NAME'],
        InvocationType='Event',
        Payload=json.dumps(event)
    )
    
    # Invoked async so we're not waiting on completion; this returns a 202 if invocation was successful
    if response['StatusCode'] == 202:
        logger.info('Invoked Jekyll builder successfully with StatusCode: {}'.format(str(response['StatusCode'])))
        return {
            "statusCode": 200,
            "body": "Jekyll builder invoked successfully"
        }
    
    # Async invocation means there will be no payload returned so can't dump it for debugging
    logger.error('Invocation of Jekyll builder failed with StatusCode: {}'.format(str(response['StatusCode'])))
    body = ''.join(['Invocation of Jekyll builder failed with StatusCode: ', str(response['StatusCode'])])
    return {
        "statusCode": 500,
        "body": body
    }
