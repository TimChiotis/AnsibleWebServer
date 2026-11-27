terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# De webservers en hun rol. Een machine erbij = een regel erbij.
locals {
  web_servers = {
    web1 = "nginx"
    web2 = "apache"
  }
}

# Het nieuwste Debian 13-image van het Debian-project
data "aws_ami" "debian13" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-13-amd64-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_key_pair" "aws_lab" {
  key_name   = "aws-lab"
  public_key = file(pathexpand(var.public_key_path))
}

# Webservers: SSH vanaf de controller, HTTP voor iedereen,
# node_exporter alleen voor monitoring1
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "SSH vanaf de controller, HTTP voor iedereen"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH vanaf my_ip_cidr"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "HTTP voor iedereen"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description     = "node_exporter alleen vanaf monitoring-sg"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.monitoring.id]
  }

  egress {
    description = "Alles naar buiten, bv. voor apt"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Monitoring: SSH, Grafana en Prometheus alleen vanaf my_ip_cidr
resource "aws_security_group" "monitoring" {
  name        = "monitoring-sg"
  description = "SSH, Grafana en Prometheus vanaf my_ip_cidr"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH vanaf my_ip_cidr"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Grafana vanaf my_ip_cidr"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Prometheus vanaf my_ip_cidr"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "Alles naar buiten: apt, Grafana-repo, scrapen op 9100"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  for_each = local.web_servers

  ami                    = data.aws_ami.debian13.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.aws_lab.key_name
  vpc_security_group_ids = [aws_security_group.web.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  # IMDSv2 verplicht, zoals de console standaard doet
  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = each.key
    Role = each.value
  }
}

resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.debian13.id
  instance_type          = var.monitoring_instance_type
  key_name               = aws_key_pair.aws_lab.key_name
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  # Iets groter: Prometheus bewaart zijn metrics op schijf
  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "monitoring1"
    Role = "monitoring"
  }
}
