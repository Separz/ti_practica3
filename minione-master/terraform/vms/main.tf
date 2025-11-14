resource "opennebula_image" "alpine" {
  name         = "Alpine Linux 3.17"
  description  = "Apline 3.17 Terraform image"
  datastore_id = 1
  persistent   = false
  lock         = "MANAGE"
  path         = "https://marketplace.opennebula.io//appliance/9fcdda10-7ae7-013b-d6f0-7875a4a4f528/download/0"
  dev_prefix   = "vd"
  driver       = "qcow2"
  permissions  = "660"
}

resource "opennebula_template" "alpine" {
  name        = "Apline Linux 3.17"
  description = "Alpine Terraform VM template"
  cpu         = 0.3
  vcpu        = 1
  memory      = 256
  permissions = "660"

  context = {
    NETWORK      = "YES"
    SET_HOSTNAME     = "$NAME"
    USERNAME     = "foo"
    PASSWORD_BASE64 = "bGludXgK"
    SSH_PUBLIC_KEY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHwA7zlUpSbbx/UjPdMxDG6T8c0PN3qniOVm5dL2ywjt noname"
  }

  graphics {
    type   = "VNC"
    listen = "0.0.0.0"
    keymap = "es"
  }

  os {
    arch = "x86_64"
    boot = "disk0"
  }

  cpumodel {
    model = "host-passthrough"
  }

  disk {
    image_id = opennebula_image.alpine.id
    size     = 1000
    target   = "vda"
    driver   = "qcow2"
  }
}

resource "opennebula_virtual_machine" "vm" {
  count = 2
  name        = "terravm-${count.index}"
  template_id = opennebula_template.alpine.id

  context = {
    SET_HOSTNAME     = "$NAME"
  }

  nic {
    network_id = 0
  }
}
