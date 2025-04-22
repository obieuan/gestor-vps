# Sistema de Contenedores Educativos - Universidad Modelo

Este sistema automatiza la creación de entornos tipo VPS para alumnos usando Docker y Portainer. 
Cada contenedor brinda acceso SSH individual y un entorno Ubuntu personalizado con las herramientas necesarias para prácticas académicas.

## 🧱 Estructura General

- Contenedores basados en imágenes personalizadas (ej. ubuntu-python3, ubuntu-fullstack, etc.)
- Asignación automática de puertos SSH, web (Django, Node, Jupyter, etc.)
- Asignación de 5 puertos adicionales por contenedor para pruebas
- Registros automáticos:
  - `puertos_usados.txt`: para evitar colisiones
  - `log.txt`: historial de creación y eliminación
  - `accesos/`: archivos con credenciales individuales

## 🛠️ Comandos Disponibles

### ➕ Crear un contenedor

```bash
./gestor_vps.sh <nombre_contenedor> <nombre_imagen>
```

Ejemplo:

```bash
./gestor_vps.sh alumno10 ubuntu-fullstack
```

### ➖ Eliminar un contenedor

```bash
./gestor_vps.sh eliminar <nombre_contenedor>
```

### 📋 Listar contenedores creados

```bash
./gestor_vps.sh listar
```

### 🧹 Verificar puertos obsoletos manualmente

```bash
./gestor_vps.sh verificar
```

## 🔐 Requisitos

- Docker instalado y corriendo en el servidor
- Acceso al mismo entorno que administra Portainer
- Las imágenes deben estar previamente construidas



## 📝 Notas

- Los accesos son individuales por contenedor, con puertos exclusivos.
- Si se elimina un contenedor desde Portainer, ejecutar `verificar` para liberar los puertos usados.
- Ideal para prácticas de programación, desarrollo web, ciencia de datos, etc.

⚠️ Este proyecto genera contraseñas y puertos automáticamente. Asegúrate de no subir los archivos:
- puertos_usados.txt
- accesos/*
- log.txt


## 📦 Catálogo de Imágenes y Servicios

| Imagen Docker             | Entorno Local | Entorno Externo | Puertos Expuestos                       | Descripción                                       |
|---------------------------|----------------|------------------|------------------------------------------|---------------------------------------------------|
| `ubuntu-python3`          | ✅              | ❌               | 2222 (SSH)                               | Ubuntu con Python 3, pip, virtualenv              |
| `ubuntu-nodejs`           | ✅              | ✅               | 2222 (SSH), 3000                         | Ubuntu con Node.js para frontend o APIs           |
| `ubuntu-fullstack`        | ✅              | ✅               | 2222 (SSH), 8000 (Django), 3000 (Node)  | Fullstack con Python/Django + Node.js             |
| `ubuntu-datascience`      | ✅              | ✅               | 2222 (SSH), 8888                         | Ubuntu con Jupyter, pandas, numpy, matplotlib     |
| `ubuntu-vscode`           | ❌              | ✅               | 8080                                     | Ubuntu con VS Code en el navegador (code-server)  |
| `ubuntu-mysql-server`     | ❌              | ✅ (opcional)    | 3306                                     | MySQL listo para conectarse desde otros sistemas  |

Todos los entornos exponen además **5 puertos extra** (rango 57000–57999) para pruebas libres, servidores auxiliares, herramientas de desarrollo, etc.



## 🔍 Consideraciones importantes

- Para que las aplicaciones web (Django, Node.js, Jupyter, etc.) sean accesibles desde el exterior, el servidor **debe estar configurado para escuchar en `0.0.0.0`**, no en `localhost`.
- Ejemplo correcto para Node.js:
  ```javascript
  app.listen(3000, '0.0.0.0');
  ```


## 🧰 Límites de Recursos por Imagen

Cada contenedor tiene asignados límites automáticos de memoria y CPU según la imagen utilizada, para evitar sobrecargar el servidor:

| Imagen Docker         | RAM Asignada | CPU Asignado | Uso Recomendado                              |
|-----------------------|--------------|--------------|-----------------------------------------------|
| ubuntu-python3        | 256 MB       | 0.5 CPU      | Scripts CLI o terminal básico                |
| ubuntu-nodejs         | 512 MB       | 1.0 CPU      | Frontend con React, Vite o Express           |
| ubuntu-fullstack      | 1 GB         | 2.0 CPU      | Proyectos completos frontend + backend       |
| ubuntu-datascience    | 2 GB         | 2.0 CPU      | Ciencia de datos con Jupyter                 |
| ubuntu-vscode         | 1 GB         | 1.5 CPU      | Desarrollo remoto vía navegador              |
| ubuntu-mysql-server   | 1 GB         | 1.0 CPU      | Base de datos para pruebas                   |

- Los contenedores tienen asignaciones de puertos internos (dentro del contenedor) hacia puertos externos (visibles en Internet). La relación exacta se indica así:

### 🧭 Relación de puertos por contenedor

| Servicio     | Puerto Interno | Puerto Externo (asignado dinámicamente) |
|--------------|----------------|-----------------------------------------|
| SSH          | 2222           | 55000–55999                             |
| Django       | 8000           | 56000–56999                             |
| Node.js      | 3000           | 56000–56999                             |
| Jupyter      | 8888           | 56000–56999                             |
| VS Code      | 8080           | 56000–56999                             |
| MySQL        | 3306           | 56000–56999 (opcional)                  |
| Extras       | (libres)       | 57000–57999                             |

---

## ⏱️ Tiempo de Vida (TTL) por Contenedor

Cada contenedor tiene un tiempo de vida predefinido según su imagen y tipo de uso. Se eliminan automáticamente mediante un proceso diario programado (cron) o con un comando manual.

| Imagen Docker         | TTL por defecto | TTL extendido (`--long`) | TTL desactivado (`--sin-ttl`) |
|-----------------------|------------------|----------------------------|-------------------------------|
| ubuntu-python3        | 4 horas          | 48 horas                  | ✅                            |
| ubuntu-nodejs         | 8 horas          | 48 horas                  | ✅                            |
| ubuntu-fullstack      | 24 horas         | 72 horas                  | ✅                            |
| ubuntu-datascience    | 24 horas         | 72 horas                  | ✅                            |
| ubuntu-vscode         | 12 horas         | 12 horas                  | ✅                            |
| ubuntu-mysql-server   | 12 horas         | 48 horas                  | ✅                            |

Todos los contenedores se crean con una etiqueta `expires_at=YYYY-MM-DDTHH:MM:SSZ`.

## 🧼 Limpieza de Contenedores Expirados

Los contenedores expirados se eliminan automáticamente con el script `limpiar_expirados.sh`.

### 🔁 Programación con `cron` (recomendado)
```bash
0 2 * * * /ruta/completa/limpiar_expirados.sh >> /var/log/ttl_cleaner.log 2>&1
```

### 🧹 Ejecución manual:
```bash
./limpiar_expirados.sh
```

### 🗂️ Registro
Las eliminaciones se registran en:
```
logs/ttl_eliminados.log
```

## ⏱️ Control de Tiempo de Vida (TTL) - Modos disponibles

El script permite controlar cuánto tiempo debe vivir un contenedor al momento de su creación.

### 🎯 Modos disponibles al crear el contenedor

- `por defecto`: se asigna un TTL corto según la imagen (ver tabla abajo)
- `--long`: asigna un TTL extendido, útil para proyectos de varios días
- `--sin-ttl`: desactiva el tiempo de vida; el contenedor se mantendrá hasta que lo elimines manualmente

### 📦 Ejemplos

```bash
# TTL corto (por defecto)
./gestor_vps.sh alumno10 ubuntu-fullstack

# TTL extendido
./gestor_vps.sh alumno11 ubuntu-fullstack --long

# Sin TTL (persistente hasta que lo elimines)
./gestor_vps.sh alumno12 ubuntu-fullstack --sin-ttl
```
