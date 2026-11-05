# Asynchronous Call Center Analytics & Summarization Pipeline

An enterprise-ready, production-grade AWS infrastructure engineered with **Terraform**, **Amazon Transcribe**, **Amazon Bedrock (Generative AI)**, **AWS Lambda**, **Amazon SQS**, **Amazon EventBridge**, and **Amazon DynamoDB**.

---

## 🏗️ Architecture & Component Design

```
[Audio File Ingest] ──> S3 Upload (Raw Bucket)
                           │
                           ▼ (S3 Event Notification)
                        SQS Queue (Ingestion) ──> DLQ (Poison Pills)
                           │
                           ▼
                        Lambda (Job Dispatcher)
                           │
                           ▼
                     Amazon Transcribe (Batch Job with Diarization)
                           │
                           ▼ (EventBridge Rule)
                        SQS Queue (Processing)
                           │
                           ▼
                        Lambda (Job Processor / Bedrock Summarizer)
                           │
                           ▼
                     S3 (Transcripts Bucket) & DynamoDB (Metadata & Analytics)
```

```mermaid
flowchart TD
    subgraph Ingestion ["1. Audio Ingestion & Buffering"]
        User(["Audio File Ingest"]) -->|PUT/Upload| RawS3["S3 Raw Audio Bucket<br/>(KMS Encrypted, Versioned)"]
        RawS3 -->|s3:ObjectCreated:*| IngestSQS["SQS Ingestion Queue<br/>(Visibility: 360s, DLQ redrive)"]
        IngestSQS -.->|Poison Pills (3 failures)| IngestDLQ["SQS Ingestion DLQ<br/>(14-Day Retention)"]
    end

    subgraph Dispatch ["2. Transcription Job Dispatch"]
        IngestSQS -->|Batch Trigger with Partial Failures| DispatchLambda["Lambda Job Dispatcher<br/>(Python 3.12, Diarization Config)"]
        DispatchLambda -->|start_transcription_job| TranscribeAPI["Amazon Transcribe<br/>(Speaker Diarization: 2-10 speakers)"]
        RawS3 -.->|Media Read via IAM Role| TranscribeAPI
    end

    subgraph StateTracking ["3. Event-Driven State Tracking"]
        TranscribeAPI -->|Job State Change: COMPLETED / FAILED| EventBridge["Amazon EventBridge Rule<br/>(Pattern: aws.transcribe)"]
        EventBridge -->|Decoupled Enqueue| ProcSQS["SQS Processing Queue<br/>(Visibility: 1800s, DLQ redrive)"]
        ProcSQS -.->|Poison Pills (3 failures)| ProcDLQ["SQS Processing DLQ<br/>(14-Day Retention)"]
    end

    subgraph Processing ["4. GenAI Analytics & Persistence"]
        TranscribeAPI -->|Output JSON| TranscriptsS3["S3 Transcripts Bucket<br/>(KMS Encrypted, Versioned)"]
        ProcSQS -->|Batch Trigger| ProcLambda["Lambda Processor & Summarizer<br/>(Converse API, Diarization Parser)"]
        TranscriptsS3 -->|Get Diarized JSON| ProcLambda
        ProcLambda -->|Converse API (Claude / Nova)| Bedrock["Amazon Bedrock<br/>(Generative AI Analytics Engine)"]
        Bedrock -->|Executive Summary, Sentiments, Topics, Actions| ProcLambda
        ProcLambda -->|Put Enriched Analytics JSON| TranscriptsS3
        ProcLambda -->|Put Item with StatusIndex & SentimentIndex| DynamoDB[("DynamoDB Table<br/>(PITR, On-Demand, TTL)")]
    end

    subgraph Observability ["5. Observability & SRE"]
        IngestDLQ -.->|Metric: MessagesVisible > 0| Alarms["CloudWatch Alarms"]
        ProcDLQ -.->|Metric: MessagesVisible > 0| Alarms
        DispatchLambda -.->|Errors > 0| Alarms
        ProcLambda -.->|Errors > 0| Alarms
        Alarms -->|Alert Notifications| SNS["SNS Alert Topic & Email"]
        Dashboard["CloudWatch Operational Dashboard"]
    end

    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:white;
    classDef storage fill:#3B48CC,stroke:#232F3E,stroke-width:2px,color:white;
    classDef compute fill:#D05C17,stroke:#232F3E,stroke-width:2px,color:white;
    classDef queue fill:#C925D1,stroke:#232F3E,stroke-width:2px,color:white;
```

---

## 🌟 Why this architecture is "Production-Grade"

1. **Decoupling with Amazon SQS**:
   - SQS queues act as shock absorbers before both Lambda functions.
   - Prevents downstream throttling during spikes (e.g. hundreds of call recordings uploaded simultaneously).
   - Tuned visibility timeouts (6x Lambda execution timeouts) prevent duplicate message processing while ensuring high throughput.
   - Concurrency limits (`scaling_config.maximum_concurrency = 50`) prevent runaway Lambda costs.

2. **Poison Pill Isolation with Dead Letter Queues (DLQs)**:
   - Corrupted audio formats, unparseable events, or temporary service faults are retried up to 3 times before being routed to dedicated DLQs with 14-day retention.
   - `ReportBatchItemFailures` is enabled on Lambda triggers, guaranteeing that a single malformed message in a batch does not cause the entire batch to re-execute.

3. **Event-Driven EventBridge State Tracking (No Polling)**:
   - Eliminates expensive polling Lambdas or Step Functions state loops waiting for hours-long transcription jobs.
   - Catches native `aws.transcribe` state transitions (`COMPLETED` or `FAILED`) via EventBridge with millisecond latency.

4. **Multi-Service Envelope Encryption (AWS KMS CMK)**:
   - Customer Managed Key (CMK) with automated 365-day rotation.
   - Unified key policy protecting S3 buckets, SQS queues, DynamoDB table, CloudWatch logs, and Amazon Transcribe data access.
   - Strict SSL enforcement denying unencrypted HTTP requests (`aws:SecureTransport: false`).

5. **Deep Diarization & Bedrock GenAI Analytics**:
   - Transcribe speaker labels (2 to 10 speakers) are parsed and reconstructed into structured conversational turns with timestamps.
   - Amazon Bedrock Converse API generates structured JSON outputs:
     - **Executive Summary**
     - **Call Reason**
     - **Customer Sentiment & Score** (-1.0 to 1.0)
     - **Agent Sentiment**
     - **Resolution Status** (`RESOLVED`, `UNRESOLVED`, `ESCALATED`, `PENDING_FOLLOWUP`)
     - **Key Topics & Action Items**
     - **Compliance Flags** (PII verification, mandatory disclosures, profanity)
     - **Call Quality Score** (1 to 10)

6. **Comprehensive Observability & SRE Runbook**:
   - CloudWatch Metric Alarms on DLQ depth, Lambda errors, and throttles.
   - CloudWatch Operational Dashboard displaying real-time queue depths, Lambda metrics, and DynamoDB consumed capacity.
   - SNS topic with email alerts for operational escalation.

---

## 📁 Repository Structure

```
aws-transcribe/
├── terraform/                          # Root Terraform working directory
│   ├── main.tf                         # Module orchestration & deterministic ARN bindings
│   ├── variables.tf                    # Root typed variables with validations
│   ├── outputs.tf                      # Root output exports from modules
│   ├── provider.tf                     # Provider declarations (AWS, Archive, Random)
│   ├── terraform.tfvars.example        # Environment variable templates
│   └── modules/                        # Production-grade decoupled modules
│       ├── kms/                        # Multi-service KMS Customer Managed Key (CMK)
│       ├── s3/                         # Raw & Transcripts buckets, versioning, TLS policy
│       ├── sqs/                        # Ingestion & Processing SQS queues + DLQs
│       ├── dynamodb/                   # Metadata & analytics table, GSIs, PITR, TTL
│       ├── lambda/                     # Dispatcher & Processor Lambdas, IAM roles & mappings
│       ├── eventbridge/                # Transcribe state change event rule & target
│       └── monitoring/                 # CloudWatch log groups, metric alarms & dashboard
├── src/
│   ├── dispatcher/
│   │   ├── handler.py                  # S3/SQS event parser & Transcribe diarization launcher
│   │   └── requirements.txt
│   └── processor/
│       ├── handler.py                  # Diarization parser, Bedrock Converse GenAI & DynamoDB writer
│       └── requirements.txt
└── tests/
    ├── sample_s3_sqs_event.json        # Test payload for Dispatcher Lambda
    ├── sample_eventbridge_sqs_event.json # Test payload for Processor Lambda
    ├── sample_transcribe_output.json   # Sample Transcribe diarization output
    └── test_handlers.py                # Local unit test runner
```

---

## 🚀 Deployment Instructions

### Prerequisites
- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [AWS CLI v2](https://aws.amazon.com/cli/) configured with appropriate administrative credentials
- Access to Amazon Bedrock foundation models (ensure `anthropic.claude-3-haiku-20240307-v1:0` or your chosen model is enabled in your AWS Bedrock Model Access console)

### Step 1: Clone & Configure
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your target settings:
```hcl
aws_region          = "us-east-1"
environment         = "production"
project_name        = "call-analytics"
bedrock_model_id    = "anthropic.claude-3-haiku-20240307-v1:0"
transcribe_max_speakers = 5
alarm_email_endpoints = ["ops-alerts@yourcompany.com"]
```

### Step 2: Initialize & Validate
```bash
terraform init
terraform validate
```

### Step 3: Plan & Apply
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

---

## 🧪 End-to-End Verification & Testing

### 1. Ingest Audio Recording
Upload an audio file (`.mp3`, `.wav`, `.flac`, `.ogg`, `.m4a`) to the Raw S3 Bucket:
```bash
RAW_BUCKET=$(terraform output -raw raw_audio_bucket_name)

aws s3 cp sample_call.mp3 "s3://${RAW_BUCKET}/recordings/call_001.mp3"
```

### 2. Monitor Ingestion & Transcription Job
Check the Dispatcher Lambda logs and Transcribe job status:
```bash
aws logs tail "/aws/lambda/$(terraform output -raw dispatcher_lambda_function_name)" --follow
aws transcribe list-transcription-jobs --status IN_PROGRESS
```

### 3. Verify GenAI Analytics Output
Once Transcribe completes, EventBridge triggers the Processing SQS queue, which executes the Processor Lambda:
```bash
aws logs tail "/aws/lambda/$(terraform output -raw processor_lambda_function_name)" --follow
```

Inspect the enriched analytics stored in S3:
```bash
TRANSCRIPTS_BUCKET=$(terraform output -raw transcripts_bucket_name)
aws s3 ls "s3://${TRANSCRIPTS_BUCKET}/analytics/"
```

Inspect the structured record in DynamoDB:
```bash
TABLE_NAME=$(terraform output -raw dynamodb_table_name)
aws dynamodb scan --table-name "$TABLE_NAME" --max-items 5
```

---

## 📊 DynamoDB Schema Reference

| Attribute | Type | Description |
|-----------|------|-------------|
| `job_id` | String (Partition Key) | Unique transcription job identifier |
| `created_at` | String (Sort Key) | ISO 8601 UTC timestamp of the event |
| `status` | String (GSI `StatusIndex`) | Processing status: `COMPLETED` or `FAILED` |
| `customer_sentiment` | String (GSI `SentimentIndex`) | `POSITIVE`, `NEUTRAL`, or `NEGATIVE` |
| `customer_sentiment_score` | Number | Sentiment intensity (-1.0 to 1.0) |
| `agent_sentiment` | String | `PROFESSIONAL`, `HELPFUL`, `EMPATHETIC`, `FRUSTRATED` |
| `resolution_status` | String | `RESOLVED`, `UNRESOLVED`, `ESCALATED`, `PENDING_FOLLOWUP` |
| `call_reason` | String | Extracted primary purpose of customer inquiry |
| `summary` | String | 2-3 sentence executive summary |
| `topics` | List of Strings | Key themes discussed |
| `action_items` | List of Strings | Specific follow-up tasks required |
| `compliance_flags` | Map | Boolean flags for PII verification, disclosures, profanity |
| `call_quality_score` | Number | 1 to 10 quality rating |
| `speaker_count` | Number | Number of detected conversation participants |
| `raw_audio_uri` | String | S3 URI of the source recording |
| `transcript_s3_uri` | String | S3 URI of raw Transcribe output JSON |
| `analytics_s3_uri` | String | S3 URI of full GenAI enriched analytics JSON |
| `model_id` | String | Bedrock model identifier used for inference |
| `processed_at` | String | Timestamp of analysis completion |
| `ttl_timestamp` | Number (TTL) | Unix epoch expiration timestamp (default: 90 days) |

---

## 🔒 Security Best Practices Implemented

- **IAM Least Privilege**: Each Lambda role contains strictly scoped actions and resource ARNs. Wildcards (`*`) are only used where required by AWS service design (e.g. `xray:PutTraceSegments`).
- **KMS Envelope Encryption**: All data at rest in S3, SQS, DynamoDB, and CloudWatch logs is encrypted via a dedicated KMS Customer Managed Key with automated rotation.
- **TLS 1.2+ Enforced**: S3 bucket policies explicitly deny insecure HTTP traffic (`aws:SecureTransport: false`).
- **S3 Public Access Block**: All four public access block settings (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) are enforced.
- **Point-in-Time Recovery (PITR)**: Enabled on DynamoDB to protect against accidental deletions or data corruption.
- **Dead Letter Isolation**: Corrupted or failing messages are quarantined to prevent head-of-line blocking and poison pill loops.

---

## 🧹 Teardown

To destroy all provisioned infrastructure:
```bash
terraform destroy
```
*(Note: If using in non-production, S3 buckets are configured with `force_destroy = true` for clean teardown. In production, buckets are protected against accidental deletion).*

