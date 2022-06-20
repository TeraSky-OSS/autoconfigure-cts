output "apps" {
  value = data.kubernetes_service.app
}

output "app_services" {
  value = local.app_services
}