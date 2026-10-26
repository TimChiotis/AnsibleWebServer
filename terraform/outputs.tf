output "public_ip" {
  description = "Publiek IP van test1"
  value       = aws_instance.test1.public_ip
}

output "private_ip" {
  description = "Privé-IP van test1"
  value       = aws_instance.test1.private_ip
}

output "ami_id" {
  description = "Het AMI dat Terraform koos"
  value       = data.aws_ami.debian13.id
}

output "ssh_command" {
  description = "Zo log je in"
  value       = "ssh -i ~/.ssh/aws-lab admin@${aws_instance.test1.public_ip}"
}
