#!/bin/bash

# === LIMPIADOR DE CONTENEDORES CON TTL ===

LOGFILE="ttl_eliminados.log"
mkdir -p logs

echo "[INFO] Buscando contenedores con etiqueta de expiración pasada..."
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

docker ps -a --filter "label=expires_at" --format '{{.ID}} {{.Label "expires_at"}}' | while read line; do
    ID=$(echo $line | awk '{print $1}')
    EXPIRES=$(echo $line | awk '{print $2}')

    if [[ "$NOW" > "$EXPIRES" ]]; then
        NAME=$(docker inspect --format='{{.Name}}' $ID | cut -c2-)
        echo "[INFO] Eliminando $NAME (expiró en $EXPIRES)"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Eliminado: $NAME - Expiró: $EXPIRES" >> logs/$LOGFILE
        docker rm -f $ID
    fi
done