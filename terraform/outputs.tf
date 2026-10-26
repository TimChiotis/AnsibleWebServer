output "ami_id" {
  description = "Het AMI dat Terraform koos"
  value       = data.aws_ami.debian13.id
}

output "public_ips" {
  description = "Publieke IP's per machine"
  value       = { for name, vm in aws_instance.web : name => vm.public_ip }
}

output "private_ips" {
  description = "Privé-IP's per machine"
  value       = { for name, vm in aws_instance.web : name => vm.private_ip }
}

output "web_urls" {
  description = "Open deze in je browser"
  value       = { for name, vm in aws_instance.web : name => "http://${vm.public_ip}" }
}

# Dezelfde groepen als in de Ansible-les
output "ansible_inventory" {
  description = "Inventory voor Ansible, in YAML"
  value = yamlencode({
    all = {
      children = {
        webservers = {
          children = {
            nginx_servers = {
              hosts = {
                web1 = { ansible_host = aws_instance.web["web1"].public_ip }
              }
            }
            apache_servers = {
              hosts = {
                web2 = { ansible_host = aws_instance.web["web2"].public_ip }
              }
            }
          }
        }
      }
    }
  })
}
