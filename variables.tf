variable "address_space" {
  type        = string
  description = "Vnet CIDR"
}
variable "subnet_config" {
  type        = map(string)
  description = "Subnet name and cidr"
}
variable "location" {
  type        = string
  default     = "France Central"
  description = "Region"
}

variable "resource_group_name" {
  type = string
}

variable "is_multi_az" {
  type    = bool
  default = false
}
variable "virtual_network_name" {
  type = string
}

variable "nat_gw" {
  
}

variable "virtual_network_subnet_ids" {
  
}
variable "localzones" {
}

