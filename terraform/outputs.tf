# Alle machines samen, voor de outputs die over alle machines gaan
locals {
  all_instances = merge(aws_instance.web, { monitoring1 = aws_instance.monitoring })
}

output "ami_id" {
  description = "Het AMI dat Terraform koos"
  value       = data.aws_ami.debian13.id
}

# dns.yml maakt een A-record voor elke naam in deze lijst
output "public_ips" {
  description = "Publieke IP's per machine"
  value       = { for name, vm in local.all_instances : name => vm.public_ip }
}

output "private_ips" {
  description = "Privé-IP's per machine"
  value       = { for name, vm in local.all_instances : name => vm.private_ip }
}

output "web_urls" {
  description = "Open deze in je browser"
  value       = { for name, vm in aws_instance.web : name => "http://${vm.public_ip}" }
}

output "monitoring_urls" {
  description = "Grafana en Prometheus, alleen bereikbaar vanaf my_ip_cidr"
  value = {
    grafana    = "http://${aws_instance.monitoring.public_ip}:3000"
    prometheus = "http://${aws_instance.monitoring.public_ip}:9090"
  }
}

# Dezelfde groepen als in de Ansible-les, plus monitoring.
# private_ip gebruikt Prometheus om de exporters te bereiken.
output "ansible_inventory" {
  description = "Inventory voor Ansible, in YAML"
  value = yamlencode({
    all = {
      children = {
        webservers = {
          children = {
            nginx_servers = {
              hosts = {
                web1 = {
                  ansible_host = aws_instance.web["web1"].public_ip
                  private_ip   = aws_instance.web["web1"].private_ip
                }
              }
            }
            apache_servers = {
              hosts = {
                web2 = {
                  ansible_host = aws_instance.web["web2"].public_ip
                  private_ip   = aws_instance.web["web2"].private_ip
                }
              }
            }
          }
        }
        monitoring = {
          hosts = {
            monitoring1 = {
              ansible_host = aws_instance.monitoring.public_ip
              private_ip   = aws_instance.monitoring.private_ip
            }
          }
        }
      }
    }
  })
}
