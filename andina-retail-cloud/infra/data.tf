resource "random_id" "suffix" {
  byte_length = 3
}

# ---------------- RDS PostgreSQL ----------------
resource "aws_db_subnet_group" "db" {
  name       = "andina-db-subnets"
  subnet_ids = [for s in aws_subnet.private_db : s.id]
  tags       = { Name = "andina-db-subnets" }
}

resource "aws_db_parameter_group" "pg16" {
  name   = "andina-pg16-tls"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "main" {
  identifier              = "db-andina"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  storage_type            = "gp3"
  storage_encrypted       = true
  db_name                 = "catalogo"
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.db.name
  parameter_group_name    = aws_db_parameter_group.pg16.name
  vpc_security_group_ids  = [aws_security_group.db.id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
  tags                    = { Name = "db-andina" }
}

# Contraseña en Parameter Store (SecureString); la VM la lee con su rol
resource "aws_ssm_parameter" "db_password" {
  name  = "/andina/db/password"
  type  = "SecureString"
  value = var.db_password
}

# ---------------- S3 (imágenes de producto) ----------------
resource "aws_s3_bucket" "media" {
  bucket        = "andina-retail-media-${random_id.suffix.hex}"
  force_destroy = true
  tags          = { Name = "andina-retail-media" }
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "media_tls" {
  bucket = aws_s3_bucket.media.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.media.arn, "${aws_s3_bucket.media.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.media]
}
