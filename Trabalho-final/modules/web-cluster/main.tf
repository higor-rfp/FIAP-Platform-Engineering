

variable "project" {
  default = "trabalho-final"
}


# Nem toda Availability Zone oferta todos os tipos de instancia. Em us-east-1, por
# exemplo, a AZ us-east-1e NAO oferta t3.micro. Descobrimos dinamicamente em quais
# AZs o tipo escolhido existe e usamos apenas as subnets dessas AZs.
data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
  location_type = "availability-zone"
}

#data "aws_vpc" "vpc" {
#  tags = {
#    Name = var.project
#  }
#}

data "aws_subnets" "all" {
  filter {
    name   = "tag:Tier"
    values = ["Public"]
  }
  filter {
    name   = "vpc-id"
    values = [aws_vpc.vpc.id]
  }
}

#data "aws_subnet" "public" {
#  for_each = toset(aws_subnets.all.ids)
#  id       = each.value
#}

locals {
  # Subnets publicas em AZs que ofertam o tipo de instancia escolhido, ordenadas
  # para um resultado deterministico (todo aluno obtem a mesma distribuicao).
  eligible_subnet_ids = sort([
    for s in aws_subnet.public_igw : s.id
    if contains(toset(data.aws_ec2_instance_type_offerings.supported.locations), s.availability_zone)
  ])

  env = terraform.workspace

  # Cada workspace tem seu proprio "tamanho" de servidor. Em dev, uma maquina
  # pequena e barata; em prod, uma maior. O mesmo codigo, parametrizado pelo
  # workspace atual — sem duplicar arquivos.
  context = {
    default = { instance_type = "t3.micro" }
    dev     = { instance_type = "t3.micro" }
    prod    = { instance_type = "t3.small" }
  }

  # lookup com fallback para 'default' caso o workspace nao esteja no mapa.
  context_variables = lookup(local.context, local.env, local.context["default"])

  node_count = lookup({ prod = 3 }, terraform.workspace, 1)
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw-${var.project}"
    env  = var.env
  }
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.project
    env  = var.env
  }
}

resource "aws_subnet" "public_igw" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, var.subnet_escale, count.index + 1)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project}_public_igw_${data.aws_availability_zones.available.names[count.index]}"
    Tier = "Public"
    env  = var.env
  }
}

# Application Load Balancer (aws_lb). Diferente do Classic ELB, o ALB opera na
# camada 7 (HTTP) e EXIGE subnets em pelo menos 2 Availability Zones — por isso
# entregamos a ele todas as subnets elegiveis, nao apenas uma.
resource "aws_lb" "web" {
  name               = "trabalho-final-alb-${local.env}"
  load_balancer_type = "application"
  subnets            = local.eligible_subnet_ids
  security_groups    = [aws_security_group.web.id]
}

# O target group agrupa os alvos (as EC2) e define como verificar a saude deles.
resource "aws_lb_target_group" "web" {
  name     = "trabalho-final-tg-${local.env}"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 6
  }
}

# O listener recebe o trafego HTTP na porta 80 e encaminha para o target group.
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# A frota de servidores. count = 2 cria duas EC2 identicas; alterar esse numero
# escala a frota para cima ou para baixo num unico apply. As instancias sao
# distribuidas entre as subnets elegiveis (AZs distintas) com element().
resource "aws_instance" "web" {
  count = var.node_count

  instance_type          = var.instance_type
  ami                    = data.aws_ami.amazon_linux.id
  subnet_id              = element(local.eligible_subnet_ids, count.index)
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = format("nginx-%s-%03d", local.env, count.index + 1)
  }
}

# Provisiona cada servidor da frota via SSM (sem SSH, sem chave). Um terraform_data
# por instancia: envia o script.sh, espera terminar e ABORTA o apply se falhar —
# mesma garantia do provisioner SSH. Exige aws CLI + jq (ver pre-requisitos do lab).
resource "terraform_data" "provisiona" {
  count = length(aws_instance.web)

  triggers_replace = {
    instance_id = aws_instance.web[count.index].id
    script_hash = filesha256("${path.module}/script.sh")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      ID="${aws_instance.web[count.index].id}"
      REGION="${var.aws_region}"

      echo "Aguardando a instancia $ID ficar online no SSM..."
      for i in $(seq 1 30); do
        PING=$(aws ssm describe-instance-information \
          --filters "Key=InstanceIds,Values=$ID" --region "$REGION" \
          --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)
        [ "$PING" = "Online" ] && break
        sleep 10
      done
      if [ "$PING" != "Online" ]; then
        echo "ERRO: a instancia $ID nao ficou online no SSM a tempo." >&2
        exit 1
      fi

      echo "Provisionando $ID via SSM..."
      COMMANDS_JSON=$(jq -R . "${path.module}/script.sh" | jq -s .)
      CMD=$(aws ssm send-command \
        --instance-ids "$ID" \
        --document-name "AWS-RunShellScript" \
        --comment "Provisionamento trabalho-final" \
        --parameters "commands=$COMMANDS_JSON" \
        --region "$REGION" \
        --query 'Command.CommandId' --output text)

      aws ssm wait command-executed --command-id "$CMD" --instance-id "$ID" --region "$REGION" || true

      echo "----- log de $ID -----"
      aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
        --region "$REGION" --query 'StandardOutputContent' --output text
      echo "----------------------"

      STATUS=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --region "$REGION" --query 'Status' --output text)
      if [ "$STATUS" != "Success" ]; then
        echo "ERRO: provisionamento de $ID falhou (Status=$STATUS)." >&2
        aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
          --region "$REGION" --query 'StandardErrorContent' --output text >&2
        exit 1
      fi
    EOT
  }
}

# Registra cada instancia da frota no target group do ALB.
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
