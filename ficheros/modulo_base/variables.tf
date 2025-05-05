variable "owner" {
  type        = string
  description = "propietario"
  validation {
    condition     = var.owner != null 
    error_message = "owner no puede ser nulo ni una cadena vacía."
  }
}

variable "entorno" {
  type        = string
  description = "entorno de la empresa"
  validation {
    condition     = contains(["dev", "pro", "tes", "pre"], lower(var.entorno))
    error_message = "entorno debe ser uno de: DEV, PRO, TES, PRE (puede ser en minusculas)."
  }
}

variable "nombre_vnet" {
  type        = string
  description = "nombre de la vnet"
  validation {
    condition     = can(regex("^vnet[a-z]{3,}tfexercise[0-9]{2,}$", var.nombre_vnet))
    error_message = "vnet_name debe empezar por 'vnet', seguido de al menos 3 letras minúsculas, y terminar en 'tfexercise' seguido de al menos dos dígitos."
  }
}

variable "vnet_tags" {
  type        = map(string)
  description = "Tags de la VNET"
  validation {
    condition = (
      var.vnet_tags != null &&
      alltrue([
        for value in values(var.vnet_tags) :
        value != null
      ])
    )
    error_message = "vnet_tags no puede ser null y ninguno de sus valores puede ser null o una cadena vacía."
  }
}
