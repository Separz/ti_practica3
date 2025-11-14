# Hoja de Ruta: Implementación de miniONE sobre Rocky Linux 9.6

## Información del Proyecto

**Asignatura**: Implementación adaptada y automatizada de plataforma IaaS
**Plataforma seleccionada**: OpenNebula (miniONE)
**Sistema Operativo**: Rocky Linux 9.6 (adaptación desde Ubuntu 22.04)
**Herramientas de automatización**: Terraform + Ansible

---

## Fase 1: Preparación del Entorno

### 1.1 Obtener imagen cloud de Rocky Linux 9.6
- **Problema identificado**: La ISO `Rocky-9.6-x86_64-minimal.iso` no funciona con cloud-init
- **Solución**: Descargar imagen cloud oficial en formato qcow2
- **Ubicación destino**: `/home/foo/vmstore/images/`
- **Comando sugerido**:
  ```bash
  cd /home/foo/vmstore/images/
  wget https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2
  ```

### 1.2 Verificar requisitos del sistema anfitrión (Arch Linux)
- [ ] Verificar libvirt instalado y activo
  ```bash
  sudo systemctl status libvirtd
  ```
- [ ] Verificar terraform instalado
  ```bash
  terraform --version
  ```
- [ ] Verificar ansible instalado
  ```bash
  ansible --version
  ```
- [ ] Crear/verificar redes libvirt necesarias:
  - Red "manage" (172.16.25.0/24)
  - Red "netstack"
- [ ] Verificar pool de almacenamiento "pool"

---

## Fase 2: Adaptación de Archivos

### 2.1 Crear estructura de directorios para Rocky Linux
```bash
cd /home/foo/ti3/minione-master/terraform/
cp -r ubuntu rocky
```

### 2.2 Modificar archivos Terraform

#### Archivo: `terraform/rocky/main.tf`
**Cambios necesarios**:
- Cambiar referencia de imagen:
  ```hcl
  # Antes (Ubuntu):
  source = "${var.path_to_image}/jammy-server-cloudimg-amd64.img"

  # Después (Rocky):
  source = "${var.path_to_image}/Rocky-9-GenericCloud-Base.latest.x86_64.qcow2"
  ```
- Ajustar hostname (opcional):
  ```hcl
  hostname = "minione-rocky"
  ```

#### Archivo: `terraform/rocky/variables.tf`
**Cambios necesarios**:
- Verificar/actualizar path a imágenes:
  ```hcl
  variable "path_to_image" {
    default = "/home/foo/vmstore/images"
  }
  ```

### 2.3 Adaptar cloud-init para Rocky Linux

#### Archivo: `terraform/rocky/config/cloud_init.cfg`

**Sección de paquetes** - Reemplazar:
```yaml
# Ubuntu:
packages:
  - qemu-guest-agent
  - python3
  - language-pack-es

# Rocky Linux:
packages:
  - qemu-guest-agent
  - python3
  - glibc-langpack-es
  - kbd
  - git
  - wget
  - epel-release
```

**Sección de comandos de configuración regional** - Reemplazar:
```yaml
# Ubuntu:
runcmd:
  - locale-gen es_CL
  - locale-gen es_CL.utf8
  - sed -i 's/XKBLAYOUT="us"/XKBLAYOUT="es"/g' /etc/default/keyboard
  - loadkeys es

# Rocky Linux:
runcmd:
  - localectl set-keymap es
  - loadkeys es
  - echo $(date -u) "- bootcmd completed" >> /root/bootcmd.log
```

### 2.4 Adaptar configuración de red

#### Archivo: `terraform/rocky/config/network_config.cfg`

**Cambios necesarios**:
```yaml
# Ubuntu usa netplan (version 2)
# Rocky Linux usa network-scripts/NetworkManager

version: 2
ethernets:
  eth0:
    dhcp4: no
    addresses:
      - 172.16.25.2/24
    gateway4: 172.16.25.1
    nameservers:
      addresses:
        - 8.8.8.8
        - 8.8.4.4
```

**Nota**: Los nombres de interfaces pueden ser diferentes:
- Ubuntu: ens3, ens4
- Rocky: eth0, eth1 (o nombres biosdevname)

### 2.5 Actualizar configuración Ansible

#### Archivo: `ansible/inventory.yml`
- Verificar IP de la VM (172.16.25.2 por defecto)
- Verificar usuario (amellado)
- Si se cambia IP en network_config.cfg, actualizar aquí también

#### Archivo: `ansible/install_minione.yml`
- Revisar que los comandos sean compatibles con Rocky Linux
- El script miniONE debería ser compatible con RHEL/Rocky

---

## Fase 3: Despliegue y Ejecución

### 3.1 Inicializar Terraform
```bash
cd /home/foo/ti3/minione-master/terraform/rocky
terraform init
```

### 3.2 Planificar despliegue
```bash
terraform plan
```
- Revisar que todos los recursos se crearán correctamente
- Verificar paths de archivos
- Verificar configuración de red

### 3.3 Aplicar configuración Terraform
```bash
sudo terraform apply
```
- Esto creará la VM con Rocky Linux 9.6
- Aplicará configuración cloud-init
- Configurará red e instalará paquetes base

### 3.4 Verificar VM creada
```bash
# Ver VMs activas
sudo virsh list

# Conectar por SSH
ssh -i ../keys/mikey amellado@172.16.25.2
```

### 3.5 Ejecutar playbook Ansible
```bash
cd /home/foo/ti3/minione-master/ansible
ansible-playbook -i inventory.yml install_minione.yml
```

### 3.6 Verificar instalación de miniONE
```bash
# Desde la VM Rocky
ssh amellado@172.16.25.2
sudo systemctl status opennebula
onehost list
onevm list
```

---

## Fase 4: Documentación y Evidencias

### 4.1 Resumen Técnico (1 página máximo)

**Incluir**:
- Cambios realizados para adaptar de Ubuntu a Rocky Linux
- Paquetes modificados y por qué
- Comandos de configuración adaptados
- Diferencias en configuración de red
- Problemas encontrados y soluciones aplicadas
- Estructura de archivos Terraform/Ansible utilizados

### 4.2 Video de demostración (6 minutos máx.)

**Contenido sugerido** (~2 min por integrante):

**Introducción (30 seg)**:
- Presentación del equipo
- Objetivo: Implementar miniONE sobre Rocky Linux usando Terraform/Ansible

**Demostración técnica (4 min)**:
- Mostrar estructura de archivos adaptados
- Ejecutar `terraform plan` o mostrar VM creada
- Mostrar diferencias clave en cloud_init.cfg
- Conectar a la VM Rocky Linux
- Demostrar miniONE funcionando (onehost list, crear VM de prueba)
- Explicar automatización Ansible

**Síntesis de mejoras (1.5 min)**:
- Cambios realizados para Rocky Linux
- Ventajas de la automatización con Terraform/Ansible
- Conclusiones del equipo

---

## Diferencias Técnicas Clave: Ubuntu vs Rocky Linux

| Aspecto | Ubuntu 22.04 | Rocky Linux 9.6 |
|---------|--------------|-----------------|
| **Imagen cloud** | jammy-server-cloudimg-amd64.img | Rocky-9-GenericCloud-Base.qcow2 |
| **Paquete de idioma** | language-pack-es | glibc-langpack-es |
| **Comando locale** | locale-gen | localectl |
| **Gestión de red** | Netplan | NetworkManager/network-scripts |
| **Repositorios extra** | universe/multiverse | EPEL |
| **Nombres interfaces** | ens3, ens4 | eth0, eth1 |
| **Familia** | Debian | RHEL |
| **Gestor paquetes** | apt | dnf/yum |

---

## Checklist de Completitud

### Preparación
- [ ] Imagen cloud Rocky 9.6 descargada
- [ ] Libvirt configurado y activo
- [ ] Terraform instalado
- [ ] Ansible instalado
- [ ] Redes libvirt creadas

### Adaptación
- [ ] Estructura terraform/rocky/ creada
- [ ] main.tf adaptado
- [ ] variables.tf actualizado
- [ ] cloud_init.cfg modificado para Rocky
- [ ] network_config.cfg adaptado
- [ ] inventory.yml verificado

### Despliegue
- [ ] terraform init ejecutado
- [ ] terraform plan revisado
- [ ] terraform apply exitoso
- [ ] VM Rocky Linux accesible por SSH
- [ ] Ansible playbook ejecutado
- [ ] miniONE instalado y funcionando

### Evidencias
- [ ] Resumen técnico redactado (1 página)
- [ ] Video grabado (máx 6 min)
- [ ] Video subido a YouTube
- [ ] Todos los integrantes participan en video

---

## Recursos y Referencias

### Repositorios locales
- **miniONE original**: `/home/foo/ti3/minione-master/`
- **Ejemplo DevStack Rocky**: `/home/foo/ti3/devstack/terraform/rocky/`
- **Claves SSH**: `/home/foo/ti3/minione-master/keys/`

### Documentación oficial
- OpenNebula miniONE: https://github.com/OpenNebula/minione
- Rocky Linux Cloud Images: https://download.rockylinux.org/pub/rocky/9/images/
- Terraform libvirt provider: https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs
- Cloud-init: https://cloudinit.readthedocs.io/

### Comandos útiles
```bash
# Limpiar fingerprint SSH si cambia VM
/home/foo/ti3/minione-master/reset_ssh_finger.sh

# Ver logs cloud-init
ssh amellado@172.16.25.2 'sudo cat /var/log/cloud-init.log'

# Destruir VM con Terraform
sudo terraform destroy

# Ver estado de libvirt
sudo virsh list --all
sudo virsh net-list --all
```

---

## Notas Importantes

1. **La ISO no sirve**: Asegurarse de usar imagen cloud qcow2, no la ISO minimal
2. **Privilegios sudo**: Terraform necesita sudo para crear VMs con libvirt
3. **Red manage**: Verificar que existe antes de aplicar Terraform
4. **Recursos mínimos**: VM necesita 8GB RAM, 2 CPU, 80GB disco
5. **Referencia devstack/rocky**: Excelente ejemplo para copiar configuraciones Rocky

---

**Última actualización**: 2025-11-13
**Siguiente paso**: Descargar imagen cloud Rocky 9.6
