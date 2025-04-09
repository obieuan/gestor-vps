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


