"""
Unit Tests for Dispatcher and Processor handlers
Verifies parsing logic, diarization parsing, and error handling locally.
"""

import json
import os
import sys
import unittest
from unittest import mock
from decimal import Decimal

# Mock AWS SDK for local unit testing when boto3 is not installed in the system Python
sys.modules["boto3"] = mock.MagicMock()
sys.modules["botocore"] = mock.MagicMock()
sys.modules["botocore.exceptions"] = mock.MagicMock()

# Set test environment variables before importing handlers
os.environ["TRANSCRIPTS_BUCKET"] = "test-transcripts-bucket"
os.environ["TRANSCRIBE_ROLE_ARN"] = "arn:aws:iam::123456789012:role/test-role"
os.environ["DYNAMODB_TABLE_NAME"] = "test-table"
os.environ["BEDROCK_MODEL_ID"] = "amazon.nova-micro-v1"

from src.dispatcher.handler import sanitize_job_name, ALLOWED_EXTENSIONS
from src.processor.handler import parse_transcribe_output, float_to_decimal


class TestAnalyticsPipeline(unittest.TestCase):

    def test_sanitize_job_name(self):
        job_name = sanitize_job_name(
            "my-bucket", "recordings/2026/call-customer-support 01.mp3"
        )
        self.assertTrue(job_name.startswith("call_"))
        self.assertIn("call-customer-support_01", job_name)
        # Ensure no spaces or invalid characters
        import re
        self.assertRegex(job_name, r"^[0-9a-zA-Z._-]+$")

    def test_allowed_extensions(self):
        self.assertIn(".mp3", ALLOWED_EXTENSIONS)
        self.assertIn(".wav", ALLOWED_EXTENSIONS)
        self.assertIn(".flac", ALLOWED_EXTENSIONS)
        self.assertNotIn(".exe", ALLOWED_EXTENSIONS)
        self.assertNotIn(".txt", ALLOWED_EXTENSIONS)

    def test_float_to_decimal(self):
        sample = {
            "score": 0.85,
            "nested": {
                "list": [1.25, 2.5, "text", 10]
            }
        }
        converted = float_to_decimal(sample)
        self.assertIsInstance(converted["score"], Decimal)
        self.assertEqual(converted["score"], Decimal("0.85"))
        self.assertIsInstance(converted["nested"]["list"][0], Decimal)
        self.assertEqual(converted["nested"]["list"][2], "text")
        self.assertEqual(converted["nested"]["list"][3], 10)

    def test_parse_transcribe_output(self):
        with open("tests/sample_transcribe_output.json", "r") as f:
            data = json.load(f)

        raw_text, diarized_transcript, speaker_count = parse_transcribe_output(data)
        self.assertIn("Acme Support", raw_text)
        self.assertEqual(speaker_count, 2)
        self.assertIn("spk_0:", diarized_transcript)
        self.assertIn("spk_1:", diarized_transcript)


if __name__ == "__main__":
    unittest.main()
