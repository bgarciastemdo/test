module "ejercicio05" {
  source      = "./modulo_base"

  owner       = var.owner
  entorno     = var.entorno
  nombre_vnet = var.nombre_vnet
  vnet_tags   = var.vnet_tags
}