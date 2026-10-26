variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "db_username" {
  type    = string
  default = "retail_app"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "image_tag" {
  type    = string
  default = "1.0.0"
}

# AWS Academy no permite crear roles IAM: se usa el perfil existente "LabInstanceProfile".
# En una cuenta Free Tier normal, poner false para crear el rol de mínimo privilegio.
variable "use_lab_role" {
  type    = bool
  default = true
}

variable "lab_instance_profile" {
  type    = string
  default = "LabInstanceProfile"
}

# Opcional: ARN de un certificado de ACM para activar HTTPS en el balanceador
variable "certificate_arn" {
  type    = string
  default = ""
}
