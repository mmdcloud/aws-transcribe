"""
Job Processor & Bedrock Summarizer Lambda Handler
Processes Transcribe Job State Change events received via SQS, retrieves
transcripts with speaker diarization, invokes Amazon Bedrock GenAI for
summarization and sentiment/topic analytics, and stores results in S3 and DynamoDB.
"""

import datetime
from decimal import Decimal
import json
import logging
import os
import re
from typing import Any, Dict, List, Optional, Tuple
import boto3
from botocore.exceptions import ClientError

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO").upper())

# AWS Clients
s3_client = boto3.client("s3")
dynamodb_resource = boto3.resource("dynamodb")
bedrock_runtime = boto3.client("bedrock-runtime")
transcribe_client = boto3.client("transcribe")

# Configuration from Environment Variables
TRANSCRIPTS_BUCKET = os.environ.get("TRANSCRIPTS_BUCKET", "")
DYNAMODB_TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME", "")
BEDROCK_MODEL_ID = os.environ.get(
    "BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0"
)
BEDROCK_MAX_TOKENS = int(os.environ.get("BEDROCK_MAX_TOKENS", "2048"))
BEDROCK_TEMPERATURE = float(os.environ.get("BEDROCK_TEMPERATURE", "0.1"))
TTL_RETENTION_DAYS = int(os.environ.get("TTL_RETENTION_DAYS", "90"))

table = dynamodb_resource.Table(DYNAMODB_TABLE_NAME) if DYNAMODB_TABLE_NAME else None


def float_to_decimal(obj: Any) -> Any:
    """Recursively converts float types to Decimal for DynamoDB serialization."""
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, dict):
        return {k: float_to_decimal(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [float_to_decimal(item) for item in obj]
    return obj


def parse_transcribe_output(transcribe_data: Dict[str, Any]) -> Tuple[str, str, int]:
    """
    Parses Transcribe JSON output to extract:
    1. Full raw transcript
    2. Speaker-diarized formatted dialogue
    3. Number of distinct speakers
    """
    results = transcribe_data.get("results", {})
    transcripts = results.get("transcripts", [])
    raw_text = transcripts[0].get("transcript", "") if transcripts else ""

    speaker_labels = results.get("speaker_labels", {})
    speaker_count = int(speaker_labels.get("speakers", 0))

    segments = speaker_labels.get("segments", [])
    items = results.get("items", [])

    if not segments or not items:
        # Fallback if diarization segments aren't present
        return raw_text, raw_text, speaker_count or 1

    # Map items by start_time for quick lookup
    # Pronunciations have start_time and end_time; punctuation has no start_time
    # AWS Transcribe speaker segments group items by speaker
    formatted_dialogue_lines: List[str] = []

    for segment in segments:
        speaker_label = segment.get("speaker_label", "Speaker")
        segment_items = segment.get("items", [])
        start_time = float(segment.get("start_time", 0.0))
        
        words: List[str] = []
        for s_item in segment_items:
            s_start = s_item.get("start_time")
            s_end = s_item.get("end_time")
            # Find matching item in items list
            # Find item corresponding to start_time
            matching = [
                i.get("alternatives", [{}])[0].get("content", "")
                for i in items
                if i.get("start_time") == s_start and i.get("end_time") == s_end
            ]
            if matching:
                words.append(matching[0])

        dialogue_text = " ".join(words).strip()
        if dialogue_text:
            minutes = int(start_time // 60)
            seconds = int(start_time % 60)
            formatted_dialogue_lines.append(
                f"[{minutes:02d}:{seconds:02d}] {speaker_label}: {dialogue_text}"
            )

    diarized_transcript = "\n".join(formatted_dialogue_lines)
    if not diarized_transcript:
        diarized_transcript = raw_text

    return raw_text, diarized_transcript, speaker_count or 1


def invoke_bedrock_analytics(diarized_transcript: str) -> Dict[str, Any]:
    """
    Invokes Amazon Bedrock Converse API with structured prompting to generate
    enterprise call center analytics, summary, sentiments, and action items.
    """
    system_prompt = (
        "You are an expert AI quality assurance and analytics engine for enterprise call centers. "
        "Analyze the following call transcript with speaker labels and output a strictly valid JSON "
        "object with no surrounding markdown or explanation."
    )

    user_prompt = f"""
Analyze this call transcript and return a JSON object with this exact structure:
{{
  "executive_summary": "Concise 2-3 sentence overview of the conversation and outcome",
  "call_reason": "Primary purpose or inquiry of the caller",
  "customer_sentiment": "POSITIVE" | "NEUTRAL" | "NEGATIVE",
  "customer_sentiment_score": float between -1.0 (extremely negative) and 1.0 (extremely positive),
  "agent_sentiment": "PROFESSIONAL" | "HELPFUL" | "EMPATHETIC" | "NEUTRAL" | "FRUSTRATED",
  "resolution_status": "RESOLVED" | "UNRESOLVED" | "ESCALATED" | "PENDING_FOLLOWUP",
  "key_topics": ["topic1", "topic2", ...],
  "action_items": ["action item 1", "action item 2", ...],
  "compliance_flags": {{
    "pii_verified": true | false,
    "mandatory_disclosure_read": true | false,
    "profanity_detected": true | false
  }},
  "call_quality_score": integer from 1 to 10
}}

Call Transcript:
\"\"\"
{diarized_transcript[:120000]}
\"\"\"
"""

    messages = [
        {
            "role": "user",
            "content": [{"text": user_prompt}],
        }
    ]

    try:
        response = bedrock_runtime.converse(
            modelId=BEDROCK_MODEL_ID,
            messages=messages,
            system=[{"text": system_prompt}],
            inferenceConfig={
                "maxTokens": BEDROCK_MAX_TOKENS,
                "temperature": BEDROCK_TEMPERATURE,
            },
        )

        response_text = ""
        output_message = response.get("output", {}).get("message", {})
        for content_block in output_message.get("content", []):
            if "text" in content_block:
                response_text += content_block["text"]

        logger.debug("Raw Bedrock Response: %s", response_text)

        # Clean markdown code blocks if the LLM wrapped JSON in ```json ... ```
        cleaned_text = re.sub(r"^```json\s*", "", response_text.strip(), flags=re.MULTILINE)
        cleaned_text = re.sub(r"```$", "", cleaned_text.strip(), flags=re.MULTILINE).strip()

        analytics_json = json.loads(cleaned_text)
        return analytics_json

    except json.JSONDecodeError as jde:
        logger.error("Failed to parse Bedrock JSON response: %s. Response was: %s", jde, response_text)
        # Fallback structured record
        return {
            "executive_summary": response_text[:500] if 'response_text' in locals() else "Summary parsing error",
            "call_reason": "Unknown (parsing error)",
            "customer_sentiment": "NEUTRAL",
            "customer_sentiment_score": 0.0,
            "agent_sentiment": "NEUTRAL",
            "resolution_status": "PENDING_FOLLOWUP",
            "key_topics": ["Analytics parsing error"],
            "action_items": ["Review raw transcript manually"],
            "compliance_flags": {
                "pii_verified": False,
                "mandatory_disclosure_read": False,
                "profanity_detected": False,
            },
            "call_quality_score": 5,
        }
    except Exception as e:
        logger.error("Bedrock invocation failed: %s", str(e), exc_info=True)
        raise


def record_failed_transcription(
    job_name: str, failure_reason: str, timestamp_iso: str
) -> None:
    """Updates DynamoDB table with FAILED status for failed Transcribe jobs."""
    if not table:
        logger.warning("DynamoDB table not configured.")
        return

    ttl_timestamp = int(
        (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=TTL_RETENTION_DAYS)).timestamp()
    )

    item = {
        "job_id": job_name,
        "created_at": timestamp_iso,
        "status": "FAILED",
        "failure_reason": failure_reason,
        "processed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "ttl_timestamp": ttl_timestamp,
    }

    logger.info("Recording failed job to DynamoDB: %s", item)
    table.put_item(Item=item)


def process_completed_transcription(
    job_name: str, event_time_iso: str
) -> None:
    """
    Retrieves the transcript from S3, executes Bedrock analytics,
    writes analytics JSON to S3, and persists record to DynamoDB.
    """
    transcript_key = f"transcripts/{job_name}.json"
    logger.info(
        "Fetching transcript from s3://%s/%s", TRANSCRIPTS_BUCKET, transcript_key
    )

    # 1. Fetch transcript from S3
    try:
        s3_resp = s3_client.get_object(
            Bucket=TRANSCRIPTS_BUCKET, Key=transcript_key
        )
        transcript_bytes = s3_resp["Body"].read()
        transcribe_data = json.loads(transcript_bytes.decode("utf-8"))
    except Exception as e:
        logger.error(
            "Failed to read transcript s3://%s/%s: %s",
            TRANSCRIPTS_BUCKET,
            transcript_key,
            str(e),
            exc_info=True,
        )
        raise

    # 2. Parse Diarization & Dialogue
    raw_text, diarized_transcript, speaker_count = parse_transcribe_output(
        transcribe_data
    )
    logger.info(
        "Parsed transcript for %s: Length: %d chars, Speakers: %d",
        job_name,
        len(raw_text),
        speaker_count,
    )

    # 3. Retrieve Audio URI & Duration from Transcribe Job
    raw_audio_uri = ""
    duration_seconds = 0.0
    try:
        job_desc = transcribe_client.get_transcription_job(
            TranscriptionJobName=job_name
        )
        job_details = job_desc.get("TranscriptionJob", {})
        raw_audio_uri = job_details.get("Media", {}).get("MediaFileUri", "")
    except Exception as ex:
        logger.warning(
            "Could not fetch full Transcribe job description for %s: %s",
            job_name,
            str(ex),
        )

    # 4. Invoke Amazon Bedrock Generative AI
    logger.info("Invoking Bedrock model %s for job %s", BEDROCK_MODEL_ID, job_name)
    analytics_result = invoke_bedrock_analytics(diarized_transcript)

    # 5. Store Enriched Analytics back to S3
    analytics_key = f"analytics/{job_name}_analytics.json"
    full_analytics_payload = {
        "job_id": job_name,
        "processed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "model_id": BEDROCK_MODEL_ID,
        "raw_audio_uri": raw_audio_uri,
        "transcript_s3_uri": f"s3://{TRANSCRIPTS_BUCKET}/{transcript_key}",
        "speaker_count": speaker_count,
        "analytics": analytics_result,
        "diarized_transcript": diarized_transcript,
    }

    try:
        s3_client.put_object(
            Bucket=TRANSCRIPTS_BUCKET,
            Key=analytics_key,
            Body=json.dumps(full_analytics_payload, indent=2).encode("utf-8"),
            ContentType="application/json",
        )
        logger.info(
            "Saved analytics to s3://%s/%s", TRANSCRIPTS_BUCKET, analytics_key
        )
    except Exception as e:
        logger.error(
            "Failed to save analytics to S3 s3://%s/%s: %s",
            TRANSCRIPTS_BUCKET,
            analytics_key,
            str(e),
            exc_info=True,
        )
        raise

    # 6. Save Metadata & Analytics to DynamoDB
    if table:
        ttl_timestamp = int(
            (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=TTL_RETENTION_DAYS)).timestamp()
        )

        db_item = {
            "job_id": job_name,
            "created_at": event_time_iso,
            "status": "COMPLETED",
            "speaker_count": speaker_count,
            "customer_sentiment": analytics_result.get(
                "customer_sentiment", "NEUTRAL"
            ),
            "customer_sentiment_score": analytics_result.get(
                "customer_sentiment_score", 0.0
            ),
            "agent_sentiment": analytics_result.get(
                "agent_sentiment", "NEUTRAL"
            ),
            "resolution_status": analytics_result.get(
                "resolution_status", "RESOLVED"
            ),
            "call_reason": analytics_result.get("call_reason", ""),
            "summary": analytics_result.get("executive_summary", ""),
            "call_quality_score": analytics_result.get("call_quality_score", 5),
            "topics": analytics_result.get("key_topics", []),
            "action_items": analytics_result.get("action_items", []),
            "compliance_flags": analytics_result.get("compliance_flags", {}),
            "raw_audio_uri": raw_audio_uri,
            "transcript_s3_uri": f"s3://{TRANSCRIPTS_BUCKET}/{transcript_key}",
            "analytics_s3_uri": f"s3://{TRANSCRIPTS_BUCKET}/{analytics_key}",
            "model_id": BEDROCK_MODEL_ID,
            "processed_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "ttl_timestamp": ttl_timestamp,
        }

        # Convert floats to Decimals for DynamoDB
        dynamo_safe_item = float_to_decimal(db_item)
        table.put_item(Item=dynamo_safe_item)
        logger.info("Persisted call analytics record into DynamoDB for %s", job_name)


def process_message_body(body_str: str) -> None:
    """Parses SQS message containing EventBridge event and dispatches processing."""
    event = json.loads(body_str)

    # EventBridge payload wrapped in SQS message
    detail_type = event.get("detail-type")
    source = event.get("source")

    if source != "aws.transcribe" or detail_type != "Transcribe Job State Change":
        logger.warning(
            "Received unexpected event source '%s' or detail-type '%s'. Body: %s",
            source,
            detail_type,
            body_str,
        )
        return

    detail = event.get("detail", {})
    job_name = detail.get("TranscriptionJobName")
    job_status = detail.get("TranscriptionJobStatus")
    event_time = event.get(
        "time", datetime.datetime.now(datetime.timezone.utc).isoformat()
    )

    if not job_name or not job_status:
        logger.error("Missing TranscriptionJobName or TranscriptionJobStatus in detail: %s", detail)
        return

    logger.info("Processing Transcribe job event: Job=%s, Status=%s", job_name, job_status)

    if job_status == "COMPLETED":
        process_completed_transcription(job_name, event_time)
    elif job_status == "FAILED":
        failure_reason = detail.get("FailureReason", "Unknown Transcribe failure")
        logger.error(
            "Transcription job %s failed. Reason: %s", job_name, failure_reason
        )
        record_failed_transcription(job_name, failure_reason, event_time)
    else:
        logger.info("Unhandled TranscriptionJobStatus '%s' for job %s", job_status, job_name)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda entrypoint for SQS trigger.
    Implements ReportBatchItemFailures protocol for graceful partial batch retry.
    """
    logger.info("Processor received event: %s", json.dumps(event))
    batch_item_failures: List[Dict[str, str]] = []

    records = event.get("Records", [])
    if not records:
        logger.info("No records in event.")
        return {"batchItemFailures": []}

    for record in records:
        message_id = record.get("messageId", "unknown")
        try:
            body_str = record.get("body", "{}")
            process_message_body(body_str)
        except Exception as ex:
            logger.error(
                "Error processing processor SQS messageId %s: %s",
                message_id,
                str(ex),
                exc_info=True,
            )
            batch_item_failures.append({"itemIdentifier": message_id})

    logger.info(
        "Processor batch complete. Total records: %d, Failures: %d",
        len(records),
        len(batch_item_failures),
    )
    return {"batchItemFailures": batch_item_failures}

