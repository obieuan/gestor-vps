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
./gestor_vps.sh [-w] [-l] [-n] <nombre_contenedor> <nombre_imagen>
```

**Opciones disponibles:**
- `-w`: activa modo web (asigna puertos adicionales si aplica)
- `-l`: asigna TTL largo (tiempo de vida extendido)
- `-n`: desactiva TTL (persistente hasta eliminación manual)

**Ejemplos:**
```bash
# TTL corto (por defecto)
./gestor_vps.sh alumno10 ubuntu-fullstack

# TTL extendido
./gestor_vps.sh -l alumno11 ubuntu-fullstack

# Sin TTL
./gestor_vps.sh -n alumno12 ubuntu-fullstack

# Modo web para ubuntu-base
./gestor_vps.sh -w alumno13 ubuntu-base
```

### ➖ Eliminar un contenedor

```bash
./gestor_vps.sh eliminar <nombre_contenedor>
```

### 📋 Listar contenedores

- Activos actualmente:
```bash
./gestor_vps.sh listar
```

- Historial completo:
```bash
./gestor_vps.sh listar --historial
```

### 🧹 Verificar puertos obsoletos

```bash
./gestor_vps.sh verificar
```

### 🛠 Mantenimiento general

```bash
./gestor_vps.sh mantenimiento
```

## 🔐 Requisitos

- Docker instalado y corriendo en el servidor
- Las imágenes deben estar previamente construidas
- Acceso SSH o consola del servidor

## 📦 Catálogo de Imágenes y Servicios

| Imagen Docker         | Servicios incluidos              | Entorno Externo | Puertos               | Descripción breve                |
|-----------------------|----------------------------------|------------------|------------------------|----------------------------------|
| ubuntu-python3        | Python, pip, virtualenv          | ❌               | SSH                   | Scripts CLI y terminal           |
| ubuntu-nodejs         | Node.js, npm                     | ✅               | SSH, 3000             | Frontend o API con Express       |
| ubuntu-fullstack      | Django + Node.js                 | ✅               | SSH, 8000, 3000       | Proyectos web completos          |
| ubuntu-datascience    | Jupyter, pandas, numpy           | ✅               | SSH, 8888             | Ciencia de datos                 |
| ubuntu-vscode         | VS Code Web                      | ✅               | 8080                  | Entorno web de desarrollo        |
| ubuntu-web            | Apache, MySQL, PHP               | ✅               | 80, 3306              | Aplicaciones PHP/MySQL          |
| ubuntu-base           | Ubuntu 22.04                     | Opcional (-w)    | SSH, 8080 (si -w)     | Imagen base para personalizar   |

**📝 Nota:** Todas las imágenes usan Ubuntu 22.04 salvo petición especial. Las solicitudes de entorno deben hacerse con al menos 24 horas de anticipación a la coordinación administrativa.

## 🧰 Recursos Asignados por Imagen

| Imagen Docker         | RAM       | CPU       | Núcleos virtuales | Uso recomendado              |
|-----------------------|-----------|-----------|--------------------|------------------------------|
| ubuntu-python3        | 256 MB    | 0.5 CPU   | 0.5 vCPU           | Scripts o práctica ligera    |
| ubuntu-nodejs         | 512 MB    | 1.0 CPU   | 1 vCPU             | Frontend simple              |
| ubuntu-fullstack      | 1 GB      | 2.0 CPU   | 2 vCPU             | Proyectos completos web      |
| ubuntu-datascience    | 2 GB      | 2.0 CPU   | 2 vCPU             | Análisis de datos            |
| ubuntu-vscode         | 1 GB      | 1.5 CPU   | 1.5 vCPU           | Desarrollo remoto            |
| ubuntu-web            | 1 GB      | 1.0 CPU   | 1 vCPU             | Sitios PHP + MySQL           |

## ⏱️ Tiempo de Vida (TTL)

| Imagen Docker         | TTL por defecto | TTL extendido (-l) | TTL desactivado (-n) |
|-----------------------|------------------|---------------------|------------------------|
| ubuntu-python3        | 24 horas          | 48 horas            | ✅                      |
| ubuntu-nodejs         | 24 horas          | 48 horas            | ✅                      |
| ubuntu-fullstack      | 48 horas          | 96 horas            | ✅                      |
| ubuntu-datascience    | 24 horas          | 72 horas            | ✅                      |
| ubuntu-web            | 48 horas          | 96 horas            | ✅                      |

## 🧼 Limpieza automática

```bash
./limpiar_expirados.sh
```

**Con cron (ejemplo recomendado):**
```bash
0 2 * * * /ruta/completa/limpiar_expirados.sh >> /var/log/ttl_cleaner.log 2>&1
```