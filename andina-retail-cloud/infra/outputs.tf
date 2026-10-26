output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.main.address
}

output "s3_bucket" {
  value = aws_s3_bucket.media.bucket
}

output "ecr_registry" {
  value = local.registry
}

output "vm_ids" {
  value = { for k, v in aws_instance.app : v.tags.Name => v.id }
}
