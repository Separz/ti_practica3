variable "oneadmin_password" {
  type        = string
  description = "Password para usuario oneadmin (vacio para leer el one_auth)"
  default     = ""
}

provider "opennebula" {
  endpoint = "http://172.16.25.2:2633/RPC2"
  username = "oneadmin"
  password = var.oneadmin_password != "" ? var.oneadmin_password : trimspace(split(":", file("${path.module}/one_auth"))[1])
}

