#!/bin/bash

# ==== CONFIGURACIÓN ====
RANGO_INICIO=55001
RANGO_FIN=55999
IMAGEN=$2
CONTENEDOR=$1
PUERTOS_USADOS="puertos_usados.txt"
PASS_LENGTH=10



# ==== OPCIÓN DE ELIMINAR CONTENEDOR ====

# ==== OPCIÓN DE LISTADO DE CONTENEDORES ====
if [ "$1" == "listar" ]; then
    echo "Contenedores activos registrados:"
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
    exit 0
fi

if [ "$1" == "eliminar" ] && [ -n "$2" ]; then
    CONTENEDOR="$2"
    echo "[INFO] Eliminando contenedor $CONTENEDOR..."
    PORT=$(docker port $CONTENEDOR 2222 | awk -F: '{print $2}')
    docker rm -f $CONTENEDOR
    if [ -n "$PORT" ]; then
        sed -i "/$PORT/d" "$PUERTOS_USADOS"
        echo "[INFO] Puerto $PORT liberado."
    fi
    echo "[INFO] Contenedor eliminado."

    echo "$(date '+%Y-%m-%d %H:%M:%S') - ELIMINADO - $CONTENEDOR - Puerto: $PORT" >> log.txt

    exit 0
fi

# ==== FUNCIONES ====

# ==== VERIFICACIÓN DE PUERTOS OBSOLETOS ====
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


# ==== DEFINICIÓN DE PUERTOS POR IMAGEN ====
declare -A PUERTOS_SERVICIOS

case "$IMAGEN" in
    "ubuntu-nodejs")
        PUERTOS_SERVICIOS[Node]=3000
        ;;
    "ubuntu-fullstack")
        PUERTOS_SERVICIOS[Django]=8000
        PUERTOS_SERVICIOS[Node]=3000
        ;;
    "ubuntu-datascience")
        PUERTOS_SERVICIOS[Jupyter]=8888
        ;;
    "ubuntu-vscode")
        PUERTOS_SERVICIOS[VSCode]=8080
        ;;
esac

# ==== FUNCIÓN: OBTENER SIGUIENTE PUERTO DISPONIBLE ====
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


# ==== ASIGNACIÓN DE PUERTOS ====
declare -A PUERTOS_EXTERNOS

# Asignar puerto SSH
PUERTO_SSH=$(get_free_port)
PUERTOS_EXTERNOS[SSH]=$PUERTO_SSH
echo "$PUERTO_SSH" >> "$PUERTOS_USADOS"

# Asignar puertos por servicio
for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    port_ext=$(get_free_port)
    PUERTOS_EXTERNOS[$servicio]=$port_ext
    echo "$port_ext" >> "$PUERTOS_USADOS"
done

# Asignar puertos extra
PUERTOS_EXTRA=()
for i in {1..5}; do
    port_extra=$(get_free_port)
    PUERTOS_EXTRA+=($port_extra)
    echo "$port_extra" >> "$PUERTOS_USADOS"
done

# ==== GENERAR OPCIONES -p PARA DOCKER ====
PORT_MAP="-p ${PUERTOS_EXTERNOS[SSH]}:2222"
for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    PORT_MAP+=" -p ${PUERTOS_EXTERNOS[$servicio]}:${PUERTOS_SERVICIOS[$servicio]}"
done


# Generar contraseña segura
generate_password() {
    tr -dc 'A-Za-z0-9@#%&!' </dev/urandom | head -c $PASS_LENGTH
}

# Obtener siguiente puerto disponible
get_next_port() {
    for ((port=RANGO_INICIO; port<=RANGO_FIN; port++)); do
        if ! grep -q "$port" "$PUERTOS_USADOS"; then
            echo $port
            return
        fi
    done
    echo "No hay puertos disponibles en el rango $RANGO_INICIO-$RANGO_FIN" >&2
    exit 1
}

# Crear usuario basado en nombre del contenedor
generate_username() {
    echo "AlumnoUM$(echo $1 | tr -cd '0-9')"
}

# ==== INICIO DEL SCRIPT ====

# ==== OPCIÓN DE LIMPIEZA MANUAL ====
if [ "$1" == "verificar" ]; then
    verificar_puertos
    echo "[INFO] Verificación completa."
    exit 0
fi

if [ -z "$CONTENEDOR" ] || [ -z "$IMAGEN" ]; then
    echo "Uso: ./crear_contenedor.sh <nombre_contenedor> <nombre_imagen>"
    exit 1
fi

PORT=$(get_next_port)
PASSWORD=$(generate_password)
USERNAME=$(generate_username $CONTENEDOR)

echo "[INFO] Creando contenedor '$CONTENEDOR' con imagen '$IMAGEN' en puerto $PORT"
echo "[INFO] Usuario: $USERNAME | Contraseña: $PASSWORD"

# Lanzar contenedor
docker run -d --name $CONTENEDOR $PORT_MAP --restart unless-stopped $IMAGEN

# Esperar un momento para que el contenedor arranque
sleep 3

# Agregar usuario y cambiar contraseña dentro del contenedor
docker exec -it $CONTENEDOR bash -c "useradd -ms /bin/bash $USERNAME && echo '$USERNAME:$PASSWORD' | chpasswd && usermod -aG sudo $USERNAME"

# Registrar puerto como usado

# Registrar evento de creación
echo "$(date '+%Y-%m-%d %H:%M:%S') - CREADO - $CONTENEDOR - Imagen: $IMAGEN - Puerto: $PORT - Usuario: $USERNAME" >> log.txt

echo "$PORT" >> "$PUERTOS_USADOS"

# Mensaje listo para enviar
echo ""
echo ""
# Crear carpeta accesos si no existe
mkdir -p accesos

# Guardar mensaje en archivo dentro de la carpeta accesos
MENSAJE="accesos/acceso_$CONTENEDOR.txt"
{
echo "Tu entorno ya está listo. Aquí están los datos de acceso:"
echo ""
echo "Servidor: $(hostname -I | awk '{print $1}')"
echo "Puerto SSH: ${PUERTOS_EXTERNOS[SSH]}"
echo "Usuario: $USERNAME"
echo "Contraseña: $PASSWORD"
for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    echo "$servicio disponible en: http://$(hostname -I | awk '{print $1}'):${PUERTOS_EXTERNOS[$servicio]}"
done
if [ ${#PUERTOS_EXTRA[@]} -gt 0 ]; then
    echo "Puertos extra para pruebas: ${PUERTOS_EXTRA[*]}"
fi
echo ""
echo "Para conectarte por SSH, ejecuta:"
echo "ssh $USERNAME@$(hostname -I | awk '{print $1}') -p ${PUERTOS_EXTERNOS[SSH]}"


# Crear carpeta accesos si no existe
mkdir -p accesos

# Guardar mensaje en archivo
MENSAJE="accesos/acceso_$CONTENEDOR.txt"
{
echo "Tu entorno ya está listo. Aquí están los datos de acceso:"
echo ""
echo "Servidor: $(hostname -I | awk '{print $1}')"
echo "Puerto SSH: ${PUERTOS_EXTERNOS[SSH]}"
echo "Usuario: $USERNAME"
echo "Contraseña: $PASSWORD"
for servicio in "${!PUERTOS_SERVICIOS[@]}"; do
    echo "$servicio → Interno: ${PUERTOS_SERVICIOS[$servicio]} | Externo: ${PUERTOS_EXTERNOS[$servicio]}"
done
if [ ${#PUERTOS_EXTRA[@]} -gt 0 ]; then
    echo "Puertos extra para pruebas: ${PUERTOS_EXTRA[*]}"
fi
echo ""
echo "Para conectarte por SSH, ejecuta:"
echo "ssh $USERNAME@$(hostname -I | awk '{print $1}') -p ${PUERTOS_EXTERNOS[SSH]}"
} > "$MENSAJE"

} | tee "$MENSAJE"

# Registrar evento de creación en log.txt
echo "$(date '+%Y-%m-%d %H:%M:%S') - CREADO - $CONTENEDOR - Imagen: $IMAGEN - Puerto: ${PUERTOS_EXTERNOS[SSH]} - Usuario: $USERNAME" >> log.txt
