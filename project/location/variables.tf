# define variables to be used in the deployment
variable "geo_location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "resource_prefix" {
  type = string
}

variable "project_address_space" {
  type = string  
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "project_count" {
  type = number
}

variable "project_subnets" {
  type = map
}

variable "terraform_script_version" {
  type = string
}

variable "admin_password" {
  type = string
}

variable "domain_name_label" {
  type = string
}

variable "vm_name" {
  type = string
}