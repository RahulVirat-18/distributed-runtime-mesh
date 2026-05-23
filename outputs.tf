output "gateway_public_ip" {
  description = "Public ingress IP for the edge API routing gateway"
  value       = aws_instance.api_gateway.public_ip
}

output "internal_cluster_private_ips" {
  description = "Private routing mesh matrix for backend worker nodes"
  value = {
    api_gateway     = aws_instance.api_gateway.private_ip
    typescript_node = aws_instance.ts_worker.private_ip
    python_node     = aws_instance.python_worker.private_ip
    telemetry_node  = aws_instance.telemetry_hub.private_ip
  }
}

output "cluster_private_key_pem" {
  description = "Natively generated private key for cluster configuration access"
  value       = tls_private_key.deploy_key.private_key_pem
  sensitive   = true
}