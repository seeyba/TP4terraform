variable "resource_group_name" {
    type= string
}
variable "location" {
    type        = string
    default     = "France Central"
    description = "Region"
  
}
variable "virtual_network_name" {
    type = string
    description = "vtnet"
}

variable "address_space" {
  type        = string
  description = "Vnet CIDR"
}
variable "is_multi_az" {
  type    = bool
  default = false
}
variable "virtual_network_subnet_ids" {
  
}
variable "lb" { 
}