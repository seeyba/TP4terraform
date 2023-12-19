output "natgw_public_ips" {
  value = [for ip in azurerm_public_ip.public_ips.*.ip_address : ip]
}