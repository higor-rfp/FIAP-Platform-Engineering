variable "aws_region" {
  description = "Regiao AWS. O Learner Lab so permite us-east-1 ou us-west-2."
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "O AWS Academy Learner Lab so permite us-east-1 ou us-west-2."
  }
}

# Busca dinamica da Amazon Linux 2023 mais recente, evitando AMIs hardcoded que expiram.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

variable "instance_type" {
  description = "Tipo de instancia EC2 da frota. Usado tambem para descobrir as AZs que o ofertam."
  default     = "t3.micro"

  # O Learner Lab so permite os tamanhos nano/micro/small/medium/large. Validar
  # aqui evita um erro tardio de "instance type not authorized" durante o apply.
  validation {
    condition     = can(regex("\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "O Learner Lab so permite tamanhos nano, micro, small, medium ou large."
  }
}

variable "node_count" {
  type    = number
}

data "aws_availability_zones" "available" {}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC. Usar faixa privada RFC 1918 (10/8, 172.16/12 ou 192.168/16)."
  default     = "10.0.0.0/16"

  # Falhe cedo: um CIDR fora das faixas privadas (ex: 9.0.0.0/16, que e espaco
  # publico da IANA) provoca conflitos de roteamento dificeis de diagnosticar.
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr precisa ser um bloco CIDR valido (ex: 10.0.0.0/16)."
  }
}

variable "subnet_escale" {
  description = "Numero de bits adicionados ao prefixo da VPC ao fatiar as subnets (cidrsubnet)."
  default     = 6
}

variable "env" {
  description = "Ambiente logico da rede."
  default     = "default"

  # Restringe a valores conhecidos: erro de digitacao vira mensagem clara no plan.
  validation {
    condition     = contains(["default","dev", "prod"], var.env)
    error_message = "env deve ser um de: default, dev, prod."
  }
}