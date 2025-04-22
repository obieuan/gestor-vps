#!/bin/bash

# ==== CONFIGURACIÓN ====
RANGO_INICIO=55001
RANGO_FIN=55999
IMAGEN=$2
CONTENEDOR=$1
PUERTOS_USADOS="puertos_usados.txt"
PASS_LENGTH=10

# ==== OPCIÓN DE MANTENIMIENTO GENERAL ====
if [ "$1" == "mantenimiento" ]; then
    echo "[🛠️  Mantenimiento General Iniciado]"
    verificar_puertos
    echo "[✔️  Puertos obsoletos liberados]"
    
    echo "[ℹ️  Contenedores activos:]"
    docker ps --format " - {{.Names}} ({{.Image}}) - Estado: {{.Status}}"

    echo "[📦 Espacio en disco por contenedor:]"
    docker system df -v | grep -E 'CONTAINER|image:' | awk '{print $1, $2, $3, $4, $5}'

    echo "[✅ Mantenimiento completo]"
    exit 0
fi

# ==== OPCIÓN DE ELIMINAR CONTENEDOR ====
if [ "$1" == "eliminar" ] && [ -n "$2" ]; then
    CONTENEDOR="$2"
    echo "[INFO] Eliminando contenedor $CONTENEDOR..."

    if docker inspect $CONTENEDOR &>/dev/null; then
        # Obtener todos los puertos externos usados por este contenedor
        docker port $CONTENEDOR | awk -F: '{print $2}' | while read port; do
            if [ -n "$port" ]; then
                sed -i "/$port/d" "$PUERTOS_USADOS"
                echo "[INFO] Puerto $port liberado."
            fi
        done

        docker rm -f $CONTENEDOR
        echo "[INFO] Contenedor eliminado."
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ELIMINADO - $CONTENEDOR - Puertos liberados" >> log.txt
    else
        echo "[WARN] El contenedor $CONTENEDOR no existe. No se puede eliminar."
    fi

    exit 0
fi

if [ "$1" == "listar" ]; then
    if [ "$2" == "--historial" ]; then        
        echo "Historial de contenedores registrados:"
        echo "----------------------------------"
        grep "CREADO" log.txt | while read -r line; do
            FECHA=$(echo $line | awk '{print $1, $2}')
            NOMBRE=$(echo $line | awk -F' - ' '{print $3}')
            IMAGEN=$(echo $line | awk -F' - ' '{print $4}' | cut -d':' -f2)
            PUERTO=$(echo $line | awk -F' - ' '{print $5}' | cut -d':' -f2)
            USUARIO=$(echo $line | awk -F' - ' '{print $6}' | cut -d':' -f2)
            echo "[$FECHA] Contenedor: $NOMBRE | Usuario: $USUARIO | Puerto SSH: $PUERTO | Imagen: $IMAGEN"
        done
        echo "----------------------------------"
    else
        echo "Contenedores actualmente activos:"
        echo "----------------------------------"
        docker ps --format '{{.Names}} {{.Image}} {{.Ports}}' | while read -r line; do
            NOMBRE=$(echo $line | awk '{print $1}')
            IMAGEN=$(echo $line | awk '{print $2}')
            echo "Contenedor: $NOMBRE | Imagen: $IMAGEN"
        done
        echo "----------------------------------"
    fi
    exit 0
fi


# ==== FUNCIONES ====
verificar_puertos() {
    echo "[INFO] Verificando puertos obsoletos..."
    touch "$PUERTOS_USADOS"
    cp "$PUERTOS_USADOS" "${PUERTOS_USADOS}.tmp"
    > "$PUERTOS_USADOS"
    while read -r port; do
        if docker ps --format '{{.Names}}' | while read name; do docker port "$name"; done | grep -q ":$port"; then
            echo "$port" >> "$PUERTOS_USADOS"
        else
            echo "[INFO] Liberado puerto no usado: $port"
        fi
    done < "${PUERTOS_USADOS}.tmp"
    rm -f "${PUERTOS_USADOS}.tmp"
}

# ==== OPCIÓN DE LIMPIEZA MANUAL ====
if [ "$1" == "verificar" ]; then
    verificar_puertos
    echo "[INFO] Verificación completa."
    exit 0
fi

# ==== VALIDACIÓN DE ENTRADAS ====
if [ -z "$CONTENEDOR" ] || [ -z "$IMAGEN" ]; then
    echo "Uso: ./gestor_vps.sh <nombre_contenedor> <nombre_imagen>"
    exit 1
fi

# ==== LIMITES DE RECURSOS SEGÚN IMAGEN ====
case "$IMAGEN" in
    "ubuntu-python3") LIMITS="--memory=256m --cpus=0.5" ;;
    "ubuntu-nodejs") LIMITS="--memory=512m --cpus=1.0" ;;
    "ubuntu-fullstack") LIMITS="--memory=1g --cpus=2.0" ;;
    "ubuntu-datascience") LIMITS="--memory=2g --cpus=2.0" ;;
    "ubuntu-vscode") LIMITS="--memory=1g --cpus=1.5" ;;
    "ubuntu-mysql-server") LIMITS="--memory=1g --cpus=1.0" ;;
    *) LIMITS="--memory=512m --cpus=1.0" ;;
esac

# ==== DEFINICIÓN DE PUERTOS POR IMAGEN ====
declare -A PUERTOS_SERVICIOS
case "$IMAGEN" in
    "ubuntu-nodejs") PUERTOS_SERVICIOS[Node]=3000 ;;
    "ubuntu-fullstack")
        PUERTOS_SERVICIOS[Django]=8000
        PUERTOS_SERVICIOS[Node]=3000 ;;
    "ubuntu-datascience") PUERTOS_SERVICIOS[Jupyter]=8888 ;;
    "ubuntu-vscode") PUERTOS_SERVICIOS[VSCode]=8080 ;;
esac

# ==== FUNCIÓN PARA ASIGNAR PUERTOS ====
get_free_port() {
    for ((port=55000; port<=59999; port++)); do
        if ! grep -q "$port" "$PUERTOS_USADOS"; then
            echo $port
            return
        fi
    done
    echo "No hay puertos disponibles." >&2
    exit 1
}

# Verificación automática antes de asignar
verificar_puertos

declare -A PUERTOS_EXTERNOS
PUERTO_SSH=$(get_free_port)
PUERTOS_EXTERNOS[SSH]=$PUERTO_SSH
echo "$PUERTO_SSH" >> "$PUERTOS_USADOS"

for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    port_ext=$(get_free_port)
    PUERTOS_EXTERNOS[$servicio]=$port_ext
    echo "$port_ext" >> "$PUERTOS_USADOS"
done

PUERTOS_EXTRA=()
for i in {1..5}; do
    port_extra=$(get_free_port)
    PUERTOS_EXTRA+=($port_extra)
    echo "$port_extra" >> "$PUERTOS_USADOS"
done

# ==== GENERAR MAPEO DE PUERTOS ====
PORT_MAP="-p ${PUERTOS_EXTERNOS[SSH]}:2222"
for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    PORT_MAP+=" -p ${PUERTOS_EXTERNOS[$servicio]}:${PUERTOS_SERVICIOS[$servicio]}"
done

# ==== CREACIÓN DE CONTENEDOR ====
PASSWORD=$(tr -dc 'A-Za-z0-9@#%&!' </dev/urandom | head -c $PASS_LENGTH)
USERNAME="AlumnoUM$(echo $CONTENEDOR | tr -cd '0-9')"

echo "[INFO] Creando contenedor '$CONTENEDOR' con imagen '$IMAGEN'"
echo "[INFO] Usuario: $USERNAME | Contraseña: $PASSWORD"

# ==== TTL AUTOMÁTICO SEGÚN IMAGEN Y MODO ====
MODO_TTL="corto"
if [ "$3" == "--long" ]; then
    MODO_TTL="largo"
fi

OMITIR_TTL=false
if [ "$3" == "--sin-ttl" ]; then
    OMITIR_TTL=true
fi

# Define TTLs en horas para cada imagen y modo
case "$IMAGEN" in
    "ubuntu-python3")
        TTL_HORAS_CORTO=4
        TTL_HORAS_LARGO=48
        ;;
    "ubuntu-nodejs")
        TTL_HORAS_CORTO=8
        TTL_HORAS_LARGO=48
        ;;
    "ubuntu-fullstack")
        TTL_HORAS_CORTO=24
        TTL_HORAS_LARGO=72
        ;;
    "ubuntu-datascience")
        TTL_HORAS_CORTO=24
        TTL_HORAS_LARGO=72
        ;;
    "ubuntu-vscode")
        TTL_HORAS_CORTO=12
        TTL_HORAS_LARGO=12
        ;;
    "ubuntu-mysql-server")
        TTL_HORAS_CORTO=12
        TTL_HORAS_LARGO=48
        ;;
    *)
        TTL_HORAS_CORTO=12
        TTL_HORAS_LARGO=24
        ;;
esac

if [ "$MODO_TTL" == "largo" ]; then
    TTL_HORAS=$TTL_HORAS_LARGO
else
    TTL_HORAS=$TTL_HORAS_CORTO
fi

# Calcular expiración en UTC ISO 8601
EXPIRES_AT=$(date -u -d "+$TTL_HORAS hours" +"%Y-%m-%dT%H:%M:%SZ")

# En docker run:
# --label expires_at="$EXPIRES_AT"

# Agregar la etiqueta solo si no se omite
ETIQUETA_TTL=""
if [ "$OMITIR_TTL" = false ]; then
    ETIQUETA_TTL="--label expires_at=\\"$EXPIRES_AT\\""
fi


docker run -d --name $CONTENEDOR $PORT_MAP $LIMITS $ETIQUETA_TTL --restart unless-stopped $IMAGEN
sleep 3

docker exec -it $CONTENEDOR bash -c "useradd -ms /bin/bash $USERNAME && echo '$USERNAME:$PASSWORD' | chpasswd && usermod -aG sudo $USERNAME"

echo "$(date '+%Y-%m-%d %H:%M:%S') - CREADO - $CONTENEDOR - Imagen: $IMAGEN - Puerto: ${PUERTOS_EXTERNOS[SSH]} - Usuario: $USERNAME" >> log.txt

mkdir -p accesos
MENSAJE="accesos/acceso_$CONTENEDOR.txt"
{
echo "Tu entorno ya está listo. Aquí están los datos de acceso:"
echo ""
echo "Servidor: $(hostname -I | awk '{print $1}')"
echo "Puerto SSH: ${PUERTOS_EXTERNOS[SSH]}"
echo "Usuario: $USERNAME"
echo "Contraseña: $PASSWORD"
echo ""
for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    echo "$servicio → Interno: ${PUERTOS_SERVICIOS[$servicio]} | Externo: ${PUERTOS_EXTERNOS[$servicio]}"
done
if [ ${#PUERTOS_EXTRA[@]} -gt 0 ]; then
    echo ""
    echo "Puertos extra para pruebas (no asignados): ${PUERTOS_EXTRA[*]}"
fi
echo ""
echo "Para conectarte por SSH, ejecuta:"
echo "ssh $USERNAME@$(hostname -I | awk '{print $1}') -p ${PUERTOS_EXTERNOS[SSH]}"
} | tee "$MENSAJE"

