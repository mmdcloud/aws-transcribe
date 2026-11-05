output "raw_audio_bucket_id" {
  description = "Name of Raw Audio S3 Bucket"
  value       = aws_s3_bucket.raw_audio.id
}

output "raw_audio_bucket_arn" {
  description = "ARN of Raw Audio S3 Bucket"
  value       = aws_s3_bucket.raw_audio.arn
}

output "transcripts_bucket_id" {
  description = "Name of Transcripts S3 Bucket"
  value       = aws_s3_bucket.transcripts.id
}

output "transcripts_bucket_arn" {
  description = "ARN of Transcripts S3 Bucket"
  value       = aws_s3_bucket.transcripts.arn
}

