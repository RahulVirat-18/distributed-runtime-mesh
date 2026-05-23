provider "aws" {
  region = var.aws_region
}

resource "aws_vpc" "aichemyst_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "aichemyst-prod-vpc"
    Environment = var.environment_tag
    ManagedBy   = "terraform"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.aichemyst_vpc.id

  tags = {
    Name        = "aichemyst-core-igw"
    Environment = var.environment_tag
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.aichemyst_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name        = "aichemyst-public-dmz"
    Environment = var.environment_tag
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.aichemyst_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "aichemyst-private-backend"
    Environment = var.environment_tag
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.aichemyst_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "aichemyst-public-rt"
    Environment = var.environment_tag
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "gateway_sg" {
  name        = "aichemyst-gateway-sg"
  description = "Ingress filtering for public edge layer"
  vpc_id      = aws_vpc.aichemyst_vpc.id

  ingress {
    description = "Engine API port"
    from_port   = 3111
    to_port     = 3111
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Telemetry viewport"
    from_port   = 61208
    to_port     = 61208
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Operator SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "aichemyst-gateway-sg"
    Environment = var.environment_tag
  }
}

resource "aws_security_group" "internal_worker_sg" {
  name        = "aichemyst-worker-sg"
  description = "Private subnet mesh isolation fabric"
  vpc_id      = aws_vpc.aichemyst_vpc.id

  ingress {
    description     = "Gateway cluster routing"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.gateway_sg.id]
  }

  ingress {
    description = "Intra-VPC mesh loop"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "aichemyst-internal-worker-sg"
    Environment = var.environment_tag
  }
}

# Generate a local deployment key pair natively to avoid external setup steps
resource "tls_private_key" "deploy_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "cluster_key" {
  key_name   = "aichemyst-cluster-key"
  public_key = tls_private_key.deploy_key.public_key_openssh
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "api_gateway" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.gateway_instance_type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.gateway_sg.id]
  key_name               = aws_key_pair.cluster_key.key_name

  tags = {
    Name        = "aichemyst-node-01-gateway"
    Role        = "api-ingress"
    Environment = var.environment_tag
  }
}

resource "aws_instance" "ts_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.internal_worker_sg.id]
  key_name               = aws_key_pair.cluster_key.key_name

  tags = {
    Name        = "aichemyst-node-02-ts-worker"
    Role        = "pipeline-logic"
    Environment = var.environment_tag
  }
}

resource "aws_instance" "python_worker" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.internal_worker_sg.id]
  key_name               = aws_key_pair.cluster_key.key_name

  tags = {
    Name        = "aichemyst-node-03-python-worker"
    Role        = "heavy-inference"
    Environment = var.environment_tag
  }
}

resource "aws_instance" "telemetry_hub" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.internal_worker_sg.id]
  key_name               = aws_key_pair.cluster_key.key_name

  tags = {
    Name        = "aichemyst-node-04-telemetry"
    Role        = "cluster-monitoring"
    Environment = var.environment_tag
  }
}