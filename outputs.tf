output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets."
  value       = aws_subnet.public[*].id
}

output "s3_bucket_name" {
  description = "Name of the private, versioned S3 bucket."
  value       = aws_s3_bucket.state.id
}