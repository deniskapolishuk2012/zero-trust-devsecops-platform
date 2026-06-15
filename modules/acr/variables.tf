variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "name_suffix" {
  description = "Short unique suffix appended to the registry name (must be globally unique, alphanumeric only)"
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}