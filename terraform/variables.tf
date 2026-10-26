variable "region" {
  description = "AWS-regio. Het Learner Lab staat alleen us-east-1 en us-west-2 toe."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Grootte van de instance."
  type        = string
  default     = "t3.micro"
}

variable "public_key_path" {
  description = "Pad naar de public key op de controller."
  type        = string
  default     = "~/.ssh/aws-lab.pub"
}

variable "my_ip_cidr" {
  description = "Het enige adres dat via SSH binnen mag, bv. 94.227.244.193/32."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "Geef een adres in CIDR-notatie, bijvoorbeeld 94.227.244.193/32."
  }
}
