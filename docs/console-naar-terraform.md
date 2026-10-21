# Van console naar Terraform

Wat we in fase B met de hand kozen, en waar het in fase C in Terraform komt.

| Keuze in de console | Onze waarde | In Terraform (fase C) |
|---|---|---|
| Regio | us-east-1 | `provider "aws"` → `region` |
| Naam | test1 | `tags = { Name = ... }` |
| AMI | ami-0b75f821522bcff85 | `data "aws_ami"` |
| Instance type | t3.micro | `instance_type` |
| Key pair | aws-lab | `resource "aws_key_pair"` |
| SSH toegestaan vanaf | 94.110.97.26/32 | `resource "aws_security_group"` |
| Opslag | 8 GiB gp3 | `root_block_device` |
| Publiek IP | 100.53.116.239 | `output` |
| Privé-IP | 172.31.30.53 | `output` |
| Gebruiker | admin | geen, bepaald door het Debian-AMI |

## Wat we zagen

- Na Stop en Start veranderde het publieke IP van 100.53.116.239 naar 3.88.179.245.
- Het privé-IP bleef 172.31.30.53.
- ssh herkende dezelfde host key onder het oude IP: dezelfde machine, nieuw adres.
