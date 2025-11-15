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

#-------------------------------------------------------------------------------
# 1. Detectar VM_NAME (Lógica Mejorada)
#-------------------------------------------------------------------------------
echo "Detectando VM_NAME..."
VM_NAME=""

# 1. Intentar desde terraform.tfvars
if [ -f "terraform.tfvars" ]; then
    VM_NAME=$(grep -m 1 -E "^\s*hostname\s*=" terraform.tfvars | sed 's/.*=\s*"\([^"]*\)".*/\1/')
fi

# 2. Si sigue vacío, intentar desde variables.tf
if [ -z "$VM_NAME" ] && [ -f "variables.tf" ]; then
    echo "  No se encontró en terraform.tfvars, buscando en variables.tf..."
    # awk: Busca el bloque 'variable "hostname"', y si lo encuentra,
    #      busca la línea 'default' dentro de ese bloque y extrae el valor.
    VM_NAME=$(awk '/variable "hostname"/ {f=1} /}/ {f=0} f && /default/ {gsub(/.*=\s*"/,""); gsub(/"/,""); print; exit}' variables.tf)
fi

# 3. Si sigue vacío, usar el valor por defecto "foo"
if [ -z "$VM_NAME" ]; then
    echo "  No se encontró en ningún archivo, usando valor por defecto 'foo'."
    VM_NAME="foo"
fi

echo -e "${GREEN}✓ VM_NAME final a usar: $VM_NAME${NC}"
echo ""


#-------------------------------------------------------------------------------
# 2. Intentar destruir con Terraform
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[1/5] Intentando destruir con Terraform...${NC}"
if terraform destroy -auto-approve; then
    echo -e "${GREEN}✓ Terraform destroy exitoso${NC}"
else
    echo -e "${RED}⚠ Terraform destroy falló, limpiando manualmente...${NC}"
fi
echo ""

#-------------------------------------------------------------------------------
# 3. Limpiar VM con virsh (por si Terraform falló)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[2/5] Limpiando VM en virsh...${NC}"

# Verificar si la VM existe
if sudo virsh list --all | grep -q " $VM_NAME "; then # Espacios para match exacto
    echo "VM '$VM_NAME' encontrada, eliminando..."

    # Paso 1: Destruir (apagar) si está corriendo
    if sudo virsh list --state-running | grep -q " $VM_NAME "; then
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
    if sudo virsh list --all | grep -q " $VM_NAME "; then
        echo -e "    ${RED}⚠ La VM aún existe, puede necesitar intervención manual${NC}"
    else
        echo -e "  ${GREEN}✓ VM eliminada completamente${NC}"
    fi
else
    echo -e "${GREEN}✓ VM '$VM_NAME' no existe en virsh${NC}"
fi
echo ""

#-------------------------------------------------------------------------------
# 4. Limpiar volúmenes huérfanos del pool (VERSIÓN MEJORADA)
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[3/5] Limpiando volúmenes huérfanos...${NC}"

# Obtener la ruta del pool
POOL_PATH=$(sudo virsh pool-dumpxml pool | grep -oP '<path>\K[^<]+' || echo "/home/foo/vmstore/pool")
echo "  Ruta del Pool detectada: $POOL_PATH"

# Obtener TODOS los volúmenes asociados a la VM
# Usamos awk para saltar las primeras 2 líneas (Cabecera y ------)
VOLUMES_TO_DELETE=$(sudo virsh vol-list pool | grep "$VM_NAME" | awk 'NR>0 {print $1}')

if [ -z "$VOLUMES_TO_DELETE" ]; then
    echo -e "  ${GREEN}✓ No se encontraron volúmenes para '$VM_NAME'${NC}"
else
    echo "  Volúmenes encontrados: $VOLUMES_TO_DELETE"
    
    # Iterar y eliminar cada uno
    for VOL in $VOLUMES_TO_DELETE; do
        echo "  -> Eliminando volumen: $VOL"
        
        # Método 1: Intentar con 'virsh vol-delete' (forma limpia)
        if sudo virsh vol-delete --pool pool "$VOL" 2>/dev/null; then
            echo "     ✓ Eliminado exitosamente con 'vol-delete'"
        else
            echo "     - 'vol-delete' falló (puede ser normal si la VM ya no existe)"
            # Método 2: Forzar borrado del archivo (forma directa)
            VOL_PATH="${POOL_PATH}/${VOL}"
            if [ -f "$VOL_PATH" ]; then
                echo "     - Intentando 'rm -f' en $VOL_PATH"
                if sudo rm -f "$VOL_PATH"; then
                    echo "     ✓ Archivo eliminado directamente"
                else
                    echo "     ${RED}⚠ Falló 'rm -f $VOL_PATH'${NC}"
                fi
            else
                echo "     - Archivo no encontrado (quizás ya fue borrado)"
            fi
        fi
    done
fi

# Refrescar el pool para que libvirt se entere de los cambios
echo "  Refrescando pool..."
sudo virsh pool-refresh pool
echo ""

#-------------------------------------------------------------------------------
# 5. Limpiar archivos de estado de Terraform
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[4/5] Limpiando archivos de Terraform...${NC}"
rm -rf .terraform*
rm -f terraform.tfstate*
echo -e "${GREEN}✓ Archivos de cache y estado eliminados${NC}"
echo ""

#-------------------------------------------------------------------------------
# 6. Verificación final
#-------------------------------------------------------------------------------
echo -e "${YELLOW}[5/5] Verificación final...${NC}"
echo ""

echo "VMs en virsh:"
if sudo virsh list --all | grep -q " $VM_NAME "; then
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
