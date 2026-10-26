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

# De machines en hun rol. Een machine erbij = een regel erbij.
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

  egress {
    description = "Alles naar buiten, bv. voor apt"
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
