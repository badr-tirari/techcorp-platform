output "instance_id" {
  description = "ID de l'instance EC2 déployée"
  value       = aws_instance.server.id
}

output "public_ip" {
  description = "Adresse IP publique (Elastic IP) de l'instance"
  value       = aws_eip.server.public_ip
}

output "ssh_connection_command" {
  description = "Commande pour se connecter en SSH à l'instance"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.server.public_ip}"
}

output "ansible_inventory_line" {
  description = "Ligne à ajouter à l'inventaire Ansible"
  value       = "${aws_eip.server.public_ip} ansible_user=ubuntu"
}

output "app_url" {
  description = "URL de l'application une fois déployée (CCP2)"
  value       = "http://${aws_eip.server.public_ip}/"
}

output "grafana_url" {
  description = "URL du dashboard Grafana une fois déployé (CCP3)"
  value       = "http://${aws_eip.server.public_ip}:3000/"
}
