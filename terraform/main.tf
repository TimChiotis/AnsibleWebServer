terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Regio — in fase B: rechtsboven in de console
provider "aws" {
  region = var.region
}

# AMI — in fase B: Quick Start > Debian
# Terraform zoekt zelf het nieuwste Debian 13-image van het Debian-project.
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

# Het standaardnetwerk dat elk AWS-account heeft
data "aws_vpc" "default" {
  default = true
}

# Key pair — in fase B: Import key pair
resource "aws_key_pair" "aws_lab" {
  key_name   = "aws-lab"
  public_key = file(pathexpand(var.public_key_path))
}

# Security group — in fase B: Network settings > SSH vanaf My IP
resource "aws_security_group" "test1" {
  name        = "test1-ssh"
  description = "SSH alleen vanaf de controller"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH vanaf my_ip_cidr"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "Alles naar buiten, bv. voor apt"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instance — in fase B: Launch instance
resource "aws_instance" "test1" {
  ami                    = data.aws_ami.debian13.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.aws_lab.key_name
  vpc_security_group_ids = [aws_security_group.test1.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "test1"
  }
}
