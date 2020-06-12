# define variables to be used in the deployment
variable "rg_name" {
  type = string
}

variable "resource_prefix" {
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

variable "terraform_script_version" {
  type = string
}

variable "domain_name_label" {
  type = string
}