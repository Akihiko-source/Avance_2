# Rol de mínimo privilegio (solo si NO se usa AWS Academy)
resource "aws_iam_role" "ec2" {
  count = var.use_lab_role ? 0 : 1
  name  = "andina-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.use_lab_role ? 0 : 1
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_caller_identity" "me" {}

resource "aws_iam_role_policy" "app" {
  count = var.use_lab_role ? 0 : 1
  name  = "andina-app-policy"
  role  = aws_iam_role.ec2[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "MediaBucketObjects", Effect = "Allow",
        Action = ["s3:GetObject", "s3:PutObject"],
        Resource = "${aws_s3_bucket.media.arn}/media/*" },
      { Sid = "MediaBucketList", Effect = "Allow",
        Action = "s3:ListBucket", Resource = aws_s3_bucket.media.arn },
      { Sid = "ReadAppSecrets", Effect = "Allow",
        Action = ["ssm:GetParameter", "ssm:GetParameters"],
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.me.account_id}:parameter/andina/*" },
      { Sid = "EcrLogin", Effect = "Allow",
        Action = "ecr:GetAuthorizationToken", Resource = "*" },
      { Sid = "EcrPull", Effect = "Allow",
        Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"],
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.me.account_id}:repository/*" }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.use_lab_role ? 0 : 1
  name  = "andina-ec2-profile"
  role  = aws_iam_role.ec2[0].name
}

locals {
  instance_profile = var.use_lab_role ? var.lab_instance_profile : aws_iam_instance_profile.ec2[0].name
}
