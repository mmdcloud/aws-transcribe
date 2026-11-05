"""
Job Dispatcher Lambda Handler
Listens to S3 upload events delivered via SQS, validates the audio file,
and initiates an Amazon Transcribe batch job with speaker diarization.
"""

import json
import logging
import os
import re
import urllib.parse
import hashlib
import time
from typing import Any, Dict, List, Optional
import boto3
from botocore.exceptions import ClientError

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# AWS Clients
transcribe_client = boto3.client("transcribe")

# Configuration from Environment Variables
TRANSCRIPTS_BUCKET = os.environ.get("TRANSCRIPTS_BUCKET", "")
TRANSCRIBE_ROLE_ARN = os.environ.get("TRANSCRIBE_ROLE_ARN", "")
DEFAULT_LANGUAGE_CODE = os.environ.get("LANGUAGE_CODE", "en-US")
ENABLE_LANGUAGE_ID = os.environ.get("ENABLE_LANGUAGE_ID", "false").lower() == "true"
MAX_SPEAKER_LABELS = int(os.environ.get("MAX_SPEAKER_LABELS", "5"))
ENVIRONMENT = os.environ.get("ENVIRONMENT", "production")

ALLOWED_EXTENSIONS = {".mp3", ".wav", ".flac", ".ogg", ".m4a", ".mp4", ".aac"}


def sanitize_job_name(bucket: str, key: str) -> str:
    """
    Generates a unique, valid Amazon Transcribe job name.
    Transcribe job name pattern: ^[0-9a-zA-Z._-]+$, max length 200 chars.
    """
    base_name = os.path.basename(key)
    stem, _ = os.path.splitext(base_name)
    sanitized_stem = re.sub(r"[^0-9a-zA-Z._-]", "_", stem)[:80]
    
    # Deterministic hash to prevent collisions and keep job name idempotent
    hash_digest = hashlib.sha256(f"{bucket}/{key}".encode("utf-8")).hexdigest()[:12]
    timestamp = int(time.time())
    
    job_name = f"call_{timestamp}_{sanitized_stem}_{hash_digest}"
    return job_name[:200]


def process_s3_record(s3_record: Dict[str, Any]) -> Optional[str]:
    """
    Parses a single S3 event record and initiates the Transcribe job.
    Returns the transcription job name on success, or None if skipped.
    """
    bucket_name = s3_record.get("bucket", {}).get("name")
    raw_key = s3_record.get("object", {}).get("key")

    if not bucket_name or not raw_key:
        logger.warning("Invalid S3 record payload: missing bucket or key: %s", s3_record)
        return None

    object_key = urllib.parse.unquote_plus(raw_key)
    logger.info("Processing S3 object: s3://%s/%s", bucket_name, object_key)

    _, ext = os.path.splitext(object_key)
    if ext.lower() not in ALLOWED_EXTENSIONS:
        logger.warning(
            "Unsupported file extension '%s' for key '%s'. Skipping. Allowed: %s",
            ext,
            object_key,
            ALLOWED_EXTENSIONS,
        )
        return None

    job_name = sanitize_job_name(bucket_name, object_key)
    media_uri = f"s3://{bucket_name}/{object_key}"
    output_key = f"transcripts/{job_name}.json"

    job_params: Dict[str, Any] = {
        "TranscriptionJobName": job_name,
        "Media": {"MediaFileUri": media_uri},
        "OutputBucketName": TRANSCRIPTS_BUCKET,
        "OutputKey": output_key,
        "Settings": {
            "ShowSpeakerLabels": True,
            "MaxSpeakerLabels": MAX_SPEAKER_LABELS,
            "ChannelIdentification": False,
        },
        "Tags": [
            {"Key": "Environment", "Value": ENVIRONMENT},
            {"Key": "SourceBucket", "Value": bucket_name},
            {"Key": "SourceKey", "Value": object_key[:255]},
            {"Key": "ManagedBy", "Value": "CallAnalyticsPipeline"},
        ],
    }

    if ENABLE_LANGUAGE_ID:
        job_params["IdentifyLanguage"] = True
    else:
        job_params["LanguageCode"] = DEFAULT_LANGUAGE_CODE

    if TRANSCRIBE_ROLE_ARN:
        job_params["JobExecutionSettings"] = {
            "DataAccessRoleArn": TRANSCRIBE_ROLE_ARN
        }

    try:
        logger.info("Starting Transcribe job: %s with params: %s", job_name, job_params)
        response = transcribe_client.start_transcription_job(**job_params)
        logger.info(
            "Successfully initiated Transcribe job %s (Status: %s)",
            job_name,
            response.get("TranscriptionJob", {}).get("TranscriptionJobStatus"),
        )
        return job_name
    except ClientError as e:
        error_code = e.response.get("Error", {}).get("Code")
        if error_code == "ConflictException":
            logger.warning(
                "Transcription job %s already exists. Skipping duplicate dispatch.",
                job_name,
            )
            return job_name
        logger.error(
            "Failed to start Transcribe job %s: %s", job_name, str(e), exc_info=True
        )
        raise


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda entrypoint for SQS trigger.
    Implements ReportBatchItemFailures protocol for graceful partial batch retry.
    """
    logger.info("Received event: %s", json.dumps(event))
    batch_item_failures: List[Dict[str, str]] = []

    records = event.get("Records", [])
    if not records:
        logger.info("No records in event.")
        return {"batchItemFailures": []}

    for record in records:
        message_id = record.get("messageId", "unknown")
        try:
            body_str = record.get("body", "{}")
            body = json.loads(body_str)

            # Check if this is an S3 Test Event
            if "Event" in body and body.get("Event") == "s3:TestEvent":
                logger.info("Received S3 Test Event. Acknowledging and skipping.")
                continue

            s3_records = body.get("Records", [])
            if not s3_records:
                # Direct S3 notification might have raw records or wrapped in SNS
                if "Message" in body:
                    try:
                        sns_body = json.loads(body["Message"])
                        s3_records = sns_body.get("Records", [])
                    except json.JSONDecodeError:
                        logger.warning("Unparseable SNS Message: %s", body["Message"])

            if not s3_records:
                logger.warning("No S3 records found in message body: %s", body_str)
                continue

            for s3_record in s3_records:
                # Handle test events inside Records
                if s3_record.get("eventName", "").startswith("s3:TestEvent"):
                    logger.info("Skipping s3:TestEvent record.")
                    continue
                s3_info = s3_record.get("s3")
                if s3_info:
                    process_s3_record(s3_info)

        except Exception as ex:
            logger.error(
                "Error processing SQS record messageId %s: %s",
                message_id,
                str(ex),
                exc_info=True,
            )
            # Add messageId to batchItemFailures so only this failed message is retried
            batch_item_failures.append({"itemIdentifier": message_id})

    logger.info(
        "Batch processing complete. Total records: %d, Failures: %d",
        len(records),
        len(batch_item_failures),
    )
    return {"batchItemFailures": batch_item_failures}

