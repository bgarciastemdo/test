variable "owner" {
  type        = string
  description = "propietario del recurso"
}

variable "entorno" {
  type        = string
  description = "entorno de la empresa"
}

variable "nombre_vnet" {
  type        = string
  description = "nombre de la vnet"
}

variable "vnet_tags" {
  type        = map(string)
  description = "Tags de la VNET"
}