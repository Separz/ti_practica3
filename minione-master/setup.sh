#!/bin/bash

#===============================================================================
# Script de configuración automática para miniONE
# Automatiza la configuración de usuario, paths y redes libvirt
#===============================================================================

set -e

echo "=========================================="
echo "  miniONE - Script de configuración"
echo "=========================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# 1. Solicitar usuario
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] Configuración de usuario${NC}"
read -p "Ingresa el nombre de usuario a usar (default: foo): " USERNAME
USERNAME=${USERNAME:-foo}
echo -e "${GREEN}✓ Usuario configurado: $USERNAME${NC}"
echo ""

#-------------------------------------------------------------------------------
# 2. Configurar redes libvirt
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/5] Configuración de redes libvirt${NC}"

# Verificar si las redes ya existen
MANAGE_EXISTS=$(sudo virsh net-list --all | grep -c " manage " || true)
NETSTACK_EXISTS=$(sudo virsh net-list --all | grep -c " netstack " || true)

if [ "$MANAGE_EXISTS" -eq 0 ]; then
    echo "Creando red 'manage'..."
    sudo virsh net-define manage.xml
    sudo virsh net-start manage
    sudo virsh net-autostart manage
    echo -e "${GREEN}✓ Red 'manage' creada${NC}"
else
    echo -e "${GREEN}✓ Red 'manage' ya existe${NC}"
fi

if [ "$NETSTACK_EXISTS" -eq 0 ]; then
    echo "Creando red 'netstack'..."
    sudo virsh net-define netstack.xml
    sudo virsh net-start netstack
    sudo virsh net-autostart netstack
    echo -e "${GREEN}✓ Red 'netstack' creada${NC}"
else
    echo -e "${GREEN}✓ Red 'netstack' ya existe${NC}"
fi
echo ""

#-------------------------------------------------------------------------------
# 3. Actualizar archivos de configuración
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/5] Actualizando archivos de configuración${NC}"

# Actualizar variables.tf (solo si no está ya configurado)
sed -i "s|default = \".*\"|default = \"$USERNAME\"|" terraform/ubuntu/variables.tf
sed -i "s|/home/.*/vmstore/images|/home/$USERNAME/vmstore/images|" terraform/ubuntu/variables.tf
echo -e "${GREEN}✓ terraform/ubuntu/variables.tf actualizado${NC}"

# Actualizar ansible inventory
sed -i "s/ansible_user=.*/ansible_user=$USERNAME/" ansible/inventory.yml
echo -e "${GREEN}✓ ansible/inventory.yml actualizado${NC}"

# Actualizar terraform/vms/main.tf
sed -i "s/USERNAME.*=.*/USERNAME     = \"$USERNAME\"/" terraform/vms/main.tf
echo -e "${GREEN}✓ terraform/vms/main.tf actualizado${NC}"
echo ""

#-------------------------------------------------------------------------------
# 4. Verificar imagen cloud
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/5] Verificando imagen cloud de Ubuntu${NC}"

IMAGE_PATH="/home/$USERNAME/vmstore/images/jammy-server-cloudimg-amd64.img"

if [ -f "$IMAGE_PATH" ]; then
    echo -e "${GREEN}✓ Imagen cloud encontrada: $IMAGE_PATH${NC}"
else
    echo -e "${RED}✗ Imagen no encontrada en: $IMAGE_PATH${NC}"
    echo ""
    read -p "¿Deseas descargarla ahora? (s/N): " DOWNLOAD
    if [[ "$DOWNLOAD" =~ ^[Ss]$ ]]; then
        echo "Descargando imagen cloud de Ubuntu 22.04..."
        mkdir -p "/home/$USERNAME/vmstore/images"
        wget -O "$IMAGE_PATH" https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
        echo -e "${GREEN}✓ Imagen descargada${NC}"
    else
        echo -e "${YELLOW}⚠ Deberás descargar la imagen manualmente antes de ejecutar terraform${NC}"
    fi
fi
echo ""

#-------------------------------------------------------------------------------
# 5. Verificar pool de almacenamiento
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[5/5] Verificando pool de almacenamiento 'pool'${NC}"

POOL_EXISTS=$(sudo virsh pool-list --all | grep -c " pool " || true)

if [ "$POOL_EXISTS" -eq 0 ]; then
    echo -e "${RED}✗ Pool 'pool' no existe${NC}"
    read -p "¿Deseas crearlo en /home/$USERNAME/vmstore/pool? (s/N): " CREATE_POOL
    if [[ "$CREATE_POOL" =~ ^[Ss]$ ]]; then
        POOL_DIR="/home/$USERNAME/vmstore/pool"
        sudo mkdir -p "$POOL_DIR"
        sudo virsh pool-define-as --name pool --type dir --target "$POOL_DIR"
        sudo virsh pool-start pool
        sudo virsh pool-autostart pool
        echo -e "${GREEN}✓ Pool 'pool' creado en $POOL_DIR${NC}"
    else
        echo -e "${YELLOW}⚠ Deberás crear el pool manualmente${NC}"
    fi
else
    echo -e "${GREEN}✓ Pool 'pool' existe${NC}"
fi
echo ""

#-------------------------------------------------------------------------------
# Resumen final
#-------------------------------------------------------------------------------
echo "=========================================="
echo -e "${GREEN}  Configuración completada${NC}"
echo "=========================================="
echo ""
echo "Siguiente paso:"
echo "  cd terraform/ubuntu"
echo "  terraform init"
echo "  terraform plan"
echo "  sudo terraform apply"
echo ""
echo "Después de crear la VM, ejecuta:"
echo "  cd ../../ansible"
echo "  ansible-playbook -i inventory.yml install_minione.yml"
echo ""
