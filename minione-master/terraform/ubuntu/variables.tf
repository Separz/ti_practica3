
variable "hostname" {
  default = "foo"
  description = "Nombre del servidor Canonical MaaS"
}

variable "domain" {
  default = "foo"
}

variable "memoryMB" {
  default = 1024*8
}

variable "cpu" {
  default = 8
}

variable "diskSize" {
  default = 80
}

variable "username" {
  default = "foo"
  description = "Usuario del sistema anfitrión y de la VM"
}

variable "path_to_image" {
  default = "/home/foo/vmstore/images"
}

