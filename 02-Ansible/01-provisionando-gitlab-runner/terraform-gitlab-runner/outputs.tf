output "ec2_dns" {
  description = "IP publico do runner (informativo)."
  value       = aws_instance.example[*].public_ip
}

output "instance_id" {
  description = "ID da instancia do runner. Use no inventario do Ansible (conexao via SSM)."
  value       = aws_instance.example[0].id
}
