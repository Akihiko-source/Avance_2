data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = { a = "us-east-1a", b = "us-east-1b" }

  public_subnets  = { a = "10.20.1.0/24",  b = "10.20.2.0/24" }
  app_subnets     = { a = "10.20.11.0/24", b = "10.20.12.0/24" }
  db_subnets      = { a = "10.20.21.0/24", b = "10.20.22.0/24" }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "andina-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-andina" }
}

resource "aws_subnet" "public" {
  for_each                = local.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[each.key]
  map_public_ip_on_launch = false
  tags                    = { Name = "public-${each.key}", Tipo = "publica" }
}

resource "aws_subnet" "private_app" {
  for_each          = local.app_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[each.key]
  tags              = { Name = "private-app-${each.key}", Tipo = "privada" }
}

resource "aws_subnet" "private_db" {
  for_each          = local.db_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[each.key]
  tags              = { Name = "private-db-${each.key}", Tipo = "aislada" }
}

# ---- NAT Gateway (uno solo, en la zona a, por costo: ADR-03) ----
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "eip-nat-andina" }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id
  tags          = { Name = "nat-andina-a" }
  depends_on    = [aws_internet_gateway.igw]
}

# ---- Tablas de ruteo ----
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "rt-public" }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "rt-private-app" }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_app" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app.id
}

# Subredes de datos: solo ruta local, sin salida a Internet
resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "rt-private-db" }
}

resource "aws_route_table_association" "private_db" {
  for_each       = aws_subnet.private_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}

# ---- VPC Endpoint de S3 (tipo Gateway) ----
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private_app.id]
  tags              = { Name = "vpce-s3" }
}

# ---- ACL de red de la subred de datos (defensa en profundidad) ----
resource "aws_network_acl" "db" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = [for s in aws_subnet.private_db : s.id]
  tags       = { Name = "nacl-db" }

  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = local.app_subnets["a"]
    from_port  = 5432
    to_port    = 5432
  }
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = local.app_subnets["b"]
    from_port  = 5432
    to_port    = 5432
  }
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = local.app_subnets["a"]
    from_port  = 1024
    to_port    = 65535
  }
  egress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = local.app_subnets["b"]
    from_port  = 1024
    to_port    = 65535
  }
}
