"""
Local End-to-End Pipeline Simulation
Simulates the entire pipeline locally without calling live AWS services:
1. Ingestion SQS event -> Dispatcher Lambda -> verifies start_transcription_job call
2. EventBridge SQS event -> Processor Lambda -> verifies transcript download, Bedrock converse call, and DynamoDB put_item
"""

import json
import os
import sys
from unittest import mock
import io

# Mock AWS SDK for local simulation
mock_boto3 = mock.MagicMock()
mock_botocore = mock.MagicMock()

sys.modules["boto3"] = mock_boto3
sys.modules["botocore"] = mock_botocore
sys.modules["botocore.exceptions"] = mock_botocore.exceptions

# Set required environment variables
os.environ["TRANSCRIPTS_BUCKET"] = "mock-transcripts-bucket"
os.environ["TRANSCRIBE_ROLE_ARN"] = "arn:aws:iam::123456789012:role/mock-transcribe-role"
os.environ["DYNAMODB_TABLE_NAME"] = "mock-analytics-table"
os.environ["BEDROCK_MODEL_ID"] = "amazon.nova-micro-v1"
os.environ["ENVIRONMENT"] = "test"
os.environ["LOG_LEVEL"] = "INFO"

# Import lambda handlers
from src.dispatcher.handler import lambda_handler as dispatcher_handler, transcribe_client
from src.processor.handler import (
    lambda_handler as processor_handler,
    s3_client,
    bedrock_runtime,
    dynamodb_resource,
    table,
)

def run_simulation():
    print("=" * 60)
    print("🧪 SIMULATING FULL PIPELINE LOCALLY")
    print("=" * 60)

    # -------------------------------------------------------------
    # 1. Test Dispatcher Lambda with Ingestion SQS Event
    # -------------------------------------------------------------
    print("\n[Step 1] Triggering Dispatcher Lambda with S3->SQS Event...")
    with open("tests/sample_s3_sqs_event.json", "r") as f:
        sqs_ingest_event = json.load(f)

    # Configure mock transcribe client
    transcribe_client.start_transcription_job.return_value = {
        "TranscriptionJob": {
            "TranscriptionJobName": "call_123456_test",
            "TranscriptionJobStatus": "IN_PROGRESS",
        }
    }

    dispatcher_response = dispatcher_handler(sqs_ingest_event, None)
    print(f"Dispatcher Response: {dispatcher_response}")
    assert dispatcher_response == {"batchItemFailures": []}, "Dispatcher reported failures!"

    # Verify Transcribe API call arguments
    assert transcribe_client.start_transcription_job.called, "start_transcription_job was not called!"
    call_kwargs = transcribe_client.start_transcription_job.call_args.kwargs
    print(f"✅ Transcribe Job Dispatched Successfully:")
    print(f"   - Job Name: {call_kwargs.get('TranscriptionJobName')}")
    print(f"   - Media URI: {call_kwargs.get('Media', {}).get('MediaFileUri')}")
    print(f"   - Diarization: {call_kwargs.get('Settings', {}).get('ShowSpeakerLabels')}")
    print(f"   - Max Speakers: {call_kwargs.get('Settings', {}).get('MaxSpeakerLabels')}")

    # -------------------------------------------------------------
    # 2. Test Processor Lambda with EventBridge SQS Event
    # -------------------------------------------------------------
    print("\n[Step 2] Triggering Processor Lambda with EventBridge->SQS Event...")
    with open("tests/sample_eventbridge_sqs_event.json", "r") as f:
        sqs_eb_event = json.load(f)

    with open("tests/sample_transcribe_output.json", "r") as f:
        sample_transcribe_json = f.read()

    # Configure mock S3 get_object to return the sample diarized transcript
    s3_client.get_object.return_value = {
        "Body": io.BytesIO(sample_transcribe_json.encode("utf-8"))
    }

    # Configure mock transcribe get_transcription_job
    transcribe_client.get_transcription_job.return_value = {
        "TranscriptionJob": {
            "Media": {"MediaFileUri": "s3://mock-raw-bucket/recordings/call_customer_support_01.mp3"}
        }
    }

    # Configure mock Bedrock Converse response
    mock_bedrock_response = {
        "output": {
            "message": {
                "content": [
                    {
                        "text": json.dumps({
                            "executive_summary": "Customer called about unexpected $45 charge. Agent identified it as an inactive add-on and issued an immediate full refund.",
                            "call_reason": "Billing discrepancy / refund request",
                            "customer_sentiment": "POSITIVE",
                            "customer_sentiment_score": 0.85,
                            "agent_sentiment": "HELPFUL",
                            "resolution_status": "RESOLVED",
                            "key_topics": ["Billing", "Refund", "Account Support"],
                            "action_items": ["None - refund successfully processed"],
                            "compliance_flags": {
                                "pii_verified": True,
                                "mandatory_disclosure_read": True,
                                "profanity_detected": False
                            },
                            "call_quality_score": 10
                        })
                    }
                ]
            }
        }
    }
    bedrock_runtime.converse.return_value = mock_bedrock_response

    processor_response = processor_handler(sqs_eb_event, None)
    print(f"Processor Response: {processor_response}")
    assert processor_response == {"batchItemFailures": []}, "Processor reported failures!"

    # Verify S3 PutObject (Enriched Analytics JSON)
    assert s3_client.put_object.called, "s3_client.put_object was not called!"
    put_s3_kwargs = s3_client.put_object.call_args.kwargs
    print(f"✅ S3 Analytics JSON Saved Successfully:")
    print(f"   - Bucket: {put_s3_kwargs.get('Bucket')}")
    print(f"   - Key: {put_s3_kwargs.get('Key')}")

    # Verify DynamoDB put_item
    assert table.put_item.called, "table.put_item was not called!"
    db_item = table.put_item.call_args.kwargs.get("Item", {})
    print(f"✅ DynamoDB Record Persisted Successfully:")
    print(f"   - Job ID: {db_item.get('job_id')}")
    print(f"   - Status: {db_item.get('status')}")
    print(f"   - Customer Sentiment: {db_item.get('customer_sentiment')}")
    print(f"   - Resolution: {db_item.get('resolution_status')}")
    print(f"   - Call Quality Score: {db_item.get('call_quality_score')}")
    print(f"   - Summary: {db_item.get('summary')}")

    print("\n" + "=" * 60)
    print("🎉 ALL LOCAL SIMULATION CHECKS PASSED!")
    print("=" * 60)

if __name__ == "__main__":
    run_simulation()
