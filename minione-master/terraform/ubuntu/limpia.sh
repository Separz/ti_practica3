#!/bin/bash

#===============================================================================
# Script mejorado de limpieza para terraform/ubuntu
# Maneja errores y limpia recursos huérfanos de virsh
#===============================================================================

set +e  # No salir en errores, queremos limpiar todo

echo "=========================================="
echo "  Limpieza de VM Ubuntu con miniONE"
echo "=========================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Obtener el nombre de la VM desde variables de Terraform
# Intenta leer desde terraform.tfvars, si no existe usa variables.tf, si falla usa "foo" por defecto
VM_NAME=$(grep -E "^\s*hostname\s*=" terraform.tfvars 2>/dev/null | sed 's/.*=\s*"\([^"]*\)".*/\1/' || \
          grep -E "default\s*=\s*\"" variables.tf | grep hostname -A1 | grep default | sed 's/.*"\(.*\)".*/\1/' || \
          echo "foo")

echo "Detectado VM_NAME: $VM_NAME"

#-------------------------------------------------------------------------------
# 1. Intentar destruir con Terraform
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Intentando destruir con Terraform...${NC}"
if terraform destroy -auto-approve; then
    echo -e "${GREEN}✓ Terraform destroy exitoso${NC}"
else
    echo -e "${RED}⚠ Terraform destroy falló, limpiando manualmente...${NC}"
fi
echo ""

#-------------------------------------------------------------------------------
# 2. Limpiar VM con virsh (por si Terraform falló)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/5] Limpiando VM en virsh...${NC}"

# Verificar si la VM existe
if sudo virsh list --all | grep -q "$VM_NAME"; then
    echo "VM '$VM_NAME' encontrada, eliminando..."

    # Paso 1: Destruir (apagar) si está corriendo
    if sudo virsh list --state-running | grep -q "$VM_NAME"; then
        echo "  Apagando VM..."
        sudo virsh destroy "$VM_NAME" 2>/dev/null || echo "    Fallo al apagar, continuando..."
        sleep 1
    fi

    # Paso 2: Intentar undefine con múltiples métodos
    echo "  Eliminando definición de VM..."

    # Método 1: Con --remove-all-storage
    if sudo virsh undefine "$VM_NAME" --remove-all-storage 2>/dev/null; then
        echo "    ✓ Eliminado con --remove-all-storage"
    # Método 2: Sin flags (volúmenes ya eliminados)
    elif sudo virsh undefine "$VM_NAME" 2>/dev/null; then
        echo "    ✓ Eliminado sin flags"
    # Método 3: Con --nvram por si tiene UEFI
    elif sudo virsh undefine "$VM_NAME" --nvram 2>/dev/null; then
        echo "    ✓ Eliminado con --nvram"
    # Método 4: Forzar con todos los flags
    elif sudo virsh undefine "$VM_NAME" --remove-all-storage --nvram 2>/dev/null; then
        echo "    ✓ Eliminado forzadamente"
    else
        echo -e "    ${RED}⚠ No se pudo eliminar automáticamente${NC}"
    fi

    # Verificar si realmente se eliminó
    if sudo virsh list --all | grep -q "$VM_NAME"; then
        echo -e "    ${RED}⚠ La VM aún existe, puede necesitar intervención manual${NC}"
    else
        echo -e "  ${GREEN}✓ VM eliminada completamente${NC}"
    fi
else
    echo -e "${GREEN}✓ VM no existe en virsh${NC}"
fi
echo ""

#-------------------------------------------------------------------------------
# 3. Limpiar volúmenes huérfanos del pool
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/5] Limpiando volúmenes huérfanos...${NC}"

# Obtener la ruta del pool
POOL_PATH=$(sudo virsh pool-dumpxml pool | grep -oP '<path>\K[^<]+' || echo "/home/foo/vmstore/pool")

# Eliminar volumen os_image
if sudo virsh vol-delete --pool pool "${VM_NAME}-os_image" 2>/dev/null; then
    echo "  ✓ Volumen os_image eliminado"
else
    # Si falla, intentar eliminar el archivo directamente
    if [ -f "${POOL_PATH}/${VM_NAME}-os_image" ]; then
        sudo rm -f "${POOL_PATH}/${VM_NAME}-os_image" && echo "  ✓ Archivo os_image eliminado directamente"
    else
        echo "  ✓ Volumen os_image no existe"
    fi
fi

# Eliminar volumen commoninit
if sudo virsh vol-delete --pool pool "${VM_NAME}-commoninit.iso" 2>/dev/null; then
    echo "  ✓ Volumen commoninit eliminado"
else
    # Si falla, intentar eliminar el archivo directamente
    if [ -f "${POOL_PATH}/${VM_NAME}-commoninit.iso" ]; then
        sudo rm -f "${POOL_PATH}/${VM_NAME}-commoninit.iso" && echo "  ✓ Archivo commoninit eliminado directamente"
    else
        echo "  ✓ Volumen commoninit no existe"
    fi
fi

# Refrescar el pool para que libvirt se entere de los cambios
sudo virsh pool-refresh pool 2>/dev/null

echo ""

#-------------------------------------------------------------------------------
# 4. Limpiar archivos de estado de Terraform
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/5] Limpiando archivos de Terraform...${NC}"
rm -rf .terraform*
rm -f terraform.tfstate*
echo -e "${GREEN}✓ Archivos de cache y estado eliminados${NC}"
echo ""

#-------------------------------------------------------------------------------
# 5. Verificación final
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[5/5] Verificación final...${NC}"
echo ""

echo "VMs en virsh:"
if sudo virsh list --all | grep "$VM_NAME"; then
    echo -e "${RED}⚠ La VM '$VM_NAME' aún existe${NC}"
else
    echo -e "${GREEN}✓ VM no encontrada${NC}"
fi

echo ""
echo "Volúmenes en pool:"
if sudo virsh vol-list pool 2>/dev/null | grep "$VM_NAME"; then
    echo -e "${RED}⚠ Aún hay volúmenes de '$VM_NAME'${NC}"
else
    echo -e "${GREEN}✓ No hay volúmenes huérfanos${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}  Limpieza completada${NC}"
echo "=========================================="
echo ""
echo "Ahora puedes ejecutar:"
echo "  terraform init"
echo "  terraform plan"
echo "  sudo terraform apply"
echo ""
