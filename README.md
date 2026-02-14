# 🏗️ ECOSISTEMA EMPRESARIAL UNIFICADO — Guía Completa de Despliegue

**Actualizado:** 14 de febrero de 2026  
**Objetivo:** Desplegar un stack completo de 7 servicios en 8 GB de RAM con Ubuntu 24.04 + Docker  
**Tiempo estimado:** 30 min (automatizado) + 10 min (primeros boots)

---

## 📋 Índice

1. [Requisitos previos](#requisitos-previos)
2. [Estructura del proyecto](#estructura-del-proyecto)
3. [Paso 1: Preparar el VPS](#paso-1-preparar-el-vps)
4. [Paso 2: Descargar/Crear los archivos](#paso-2-descargar-crear-los-archivos)
5. [Paso 3: Ejecutar setup.sh](#paso-3-ejecutar-setupsh)
6. [Paso 4: Arrancar Docker Compose](#paso-4-arrancar-docker-compose)
7. [Paso 5: Configurar Nginx Proxy Manager](#paso-5-configurar-nginx-proxy-manager)
8. [Paso 6: Crear Vista global de usuarios](#paso-6-crear-vista-global-de-usuarios)
9. [Paso 7: Conectar ToolJet a MariaDB](#paso-7-conectar-tooljet-a-mariadb)
10. [Paso 8: Validar el stack](#paso-8-validar-el-stack)
11. [Troubleshooting](#troubleshooting)
12. [Comandos útiles](#comandos-útiles)

---

## ✅ Requisitos previos

```bash
# En tu VPS (Ubuntu 24.04):
- Docker >= 24.0 (instalado)
- Docker Compose >= 2.0 (instalado con Docker Desktop)
- 4 vCPU + 8 GB RAM + 75 GB NVMe (mínimo)
- Acceso root o sudo sin contraseña
- Dominios apuntando a tu IP VPS (opcional, para desarrollo usar hosts locales)
```

**Verificar Docker:**
```bash
docker --version
docker compose version
```

---

## 📁 Estructura del proyecto

Después de ejecutar `setup.sh`, la carpeta se verá así:

```
/home/tu_usuario/ecosistema/
├── .env                              # Variables de entorno (SECRETO)
├── .gitignore                        # Excluir archivos sensibles
├── docker-compose.yml                # Stack completo
├── init.sql                         # Inicialización de BD
├── setup.sh                         # Script de automatización
├── README.md                        # Este archivo
├── docker_data/                     # Volúmenes persistentes
│   ├── npm/data/                    # Config Nginx Proxy Manager
│   ├── npm/letsencrypt/             # Certificados SSL
│   ├── mariadb/                     # Base de datos
│   ├── redis/                       # Caché Redis
│   ├── wordpress/                   # Archivos WordPress
│   ├── moodle/                      # Código Moodle
│   ├── moodledata/                  # Datos de Moodle
│   └── tooljet-db/                  # PostgreSQL de ToolJet
└── backups/                         # Carpeta para backups (créala manual)
```

---

## Paso 1: Preparar el VPS

### 1.1 → SSH a tu servidor

```bash
ssh usuario@tu_vps_ip
```

### 1.2 → Crear carpeta de trabajo

```bash
mkdir -p ~/ecosistema && cd ~/ecosistema
```

### 1.3 → Crear compartición de swap (CRÍTICO para 8 GB)

```bash
# Crear swap de 4 GB (mayor que RAM, por si acaso)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Hacerlo permanente
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verificar
swapon --show
free -h
```

**Output esperado:**
```
              total        used        free      shared  buff/cache   available
Mem:          7.8Gi       2.1Gi       3.2Gi      256Mi       2.2Gi       5.3Gi
Swap:         4.0Gi          0B       4.0Gi
```

### 1.4 → Ajustar límites de FDs (open files)

```bash
# Para manejar múltiples conexiones sin errores
sudo bash -c 'echo "* soft nofile 65536" >> /etc/security/limits.conf'
sudo bash -c 'echo "* hard nofile 65536" >> /etc/security/limits.conf'

# Recargar sesión (logout + login, o source)
sudo sysctl -p
```

---

## Paso 2: Descargar/Crear los archivos

### Opción A: Clonar desde Git (si lo subiste al repositorio)

```bash
cd ~/ecosistema
git clone https://tu_repo.git .
```

### Opción B: Crear manualmente los archivos

Copia el contenido de cada archivo en tu editor local y luego:

**En tu máquina local**, crea los 4 archivos principales:
- `.env`
- `docker-compose.yml`
- `init.sql`
- `.gitignore`

Luego **sube todo al VPS** vía SCP:

```bash
# Desde tu máquina local:
scp -r .env docker-compose.yml init.sql .gitignore \
  usuario@tu_vps_ip:~/ecosistema/
```

### Opción C: Crear directamente en el VPS (nano/vim)

```bash
# En el VPS:
cd ~/ecosistema

# Copiar el contenido de .env
nano .env
# (pegar contenido, Ctrl+O, Enter, Ctrl+X)

# Repetir para los otros archivos...
nano docker-compose.yml
nano init.sql
nano .gitignore
```

**Verificar que los archivos están:**
```bash
ls -la ~/ecosistema/
# Debe mostrar: .env, docker-compose.yml, init.sql, .gitignore
```

---

## Paso 3: Ejecutar setup.sh

El script automatiza:
- ✅ Crear carpetas de volúmenes (`docker_data/*`)
- ✅ Asignar permisos correctos
- ✅ Validar que Docker está corriendo
- ✅ Crear red de Docker
- ✅ Mostrar un resumen final

### 3.1 → Descargar o crear setup.sh

**En el VPS:**
```bash
cd ~/ecosistema

# Si NO tienes el archivo, créalo con nano:
nano setup.sh
```

Pega el contenido de `setup.sh` (ver sección siguiente).

### 3.2 → Dar permisos de ejecución

```bash
chmod +x setup.sh
```

### 3.3 → Ejecutar

```bash
./setup.sh
```

**Output esperado:**
```
╔════════════════════════════════════════════════════════════╗
║ ECOSISTEMA EMPRESARIAL UNIFICADO — Setup Automatizado       ║
╚════════════════════════════════════════════════════════════╝

✓ Verificando Docker...
✓ Creando estructura de carpetas...
✓ Estableciendo permisos...
✓ Validando archivos principales...
✓ Verificando espacios en disco...

[OK] Setups completado. Listo para: docker compose up -d
```

---

## Paso 4: Arrancar Docker Compose

### 4.1 → Levantamiento ordenado

```bash
cd ~/ecosistema

# Ver logs en vivo (otra terminal):
# docker compose logs -f

# En la terminal principal:
docker compose up -d

# Esperar 5-10 segundos
sleep 10

# Verificar estado
docker compose ps
```

**Output esperado después de `docker compose ps`:**
```
NAME           IMAGE                               STATUS
npm            jc21/nginx-proxy-manager:latest    Up 30s
mariadb        mariadb:10.11                      Up 30s (health: starting)
redis          redis:7-alpine                     Up 30s
wordpress      wordpress:latest                   Up 30s
moodle         bitnami/moodle:latest              Up 30s
tooljet-db     postgres:15-alpine                 Up 30s (health: starting)
tooljet        tooljet/tooljet-ce:latest          Up 30s
```

### 4.2 → Monitorizar los primeros logs

```bash
# En otra terminal (keep it open):
docker compose logs -f

# O filtrar solo errores:
docker compose logs -f | grep -i error
```

**Puntos de verificación:**

| Servicio | Tiempo boot | Señal de éxito |
|---|---|---|
| NPM | 10 s | `Listening on port 80, 443, 81` |
| MariaDB | 15 s | `[Server] ready for connections` |
| Redis | 5 s | ✓ inmediato |
| WordPress | 20 s | `Apache started` |
| Moodle | 2-5 min | `Moodle installed succesfully` o logs sin errores fatales |
| PostgreSQL | 10 s | `database system is ready` |
| ToolJet | 30 s | `Server is running` |

---

## Paso 5: Configurar Nginx Proxy Manager

### 5.1 → Acceder al panel

Abre en el navegador: `http://tu_vps_ip:81`

Login por defecto:
- **Email:** `admin@example.com`
- **Contraseña:** `changeme`

### 5.2 → Cambiar contraseña del admin (INMEDIATO)

En el panel → Settings → Users → Edit admin → Change Password

### 5.3 → Crear 3 Proxy Hosts

Ir a **Proxy Hosts** → **Add Proxy Host**

#### Proxy Host 1: WordPress (SANA Web)

| Campo | Valor |
|---|---|
| **Domain Names** | `www.sana.es` (o tu dominio) |
| **Scheme** | `http` |
| **Forward Hostname** | `wordpress` |
| **Forward Port** | `80` |
| **Access List** | `Public` |
| **Cache Assets** | ✓ Activar |
| **Block Common Exploits** | ✓ Activar |
| **Websockets Support** | ✗ (no necesario) |

En la tab **SSL**:
- **SSL Certificate:** `Let's Encrypt` (si tienes dominio) o `Self-Signed`
- **Force SSL:** ✓ (activar)
- **HTTP/2 Support:** ✓

**Save → Esperar 30s**

#### Proxy Host 2: Moodle (SANA Academy)

| Campo | Valor |
|---|---|
| **Domain Names** | `academy.sana.es` |
| **Scheme** | `http` |
| **Forward Hostname** | `moodle` |
| **Forward Port** | `8080` |
| **Access List** | `Public` |
| **Websockets Support** | ✓ Activar (importante para Moodle) |

SSL: Same as above

#### Proxy Host 3: ToolJet (ERP)

| Campo | Valor |
|---|---|
| **Domain Names** | `erp.sana.es` |
| **Scheme** | `http` |
| **Forward Hostname** | `tooljet` |
| **Forward Port** | `3000` |
| **Access List** | `Public` |
| **Websockets Support** | ✓ Activar (crítico para ToolJet) |

SSL: Same as above

### 5.4 → Testear acceso en localhost (sin dominio)

Si no tienes dominio registrado, agrega a `/etc/hosts` (en tu máquina local):

```bash
# En tu máquina (macOS/Linux):
sudo nano /etc/hosts

# Añade:
tu_vps_ip  www.sana.es
tu_vps_ip  academy.sana.es
tu_vps_ip  erp.sana.es
```

Luego accede a `http://www.sana.es`, etc.

---

## Paso 6: Crear Vista global de usuarios

Tras 3-5 minutos (cuando Moodle termine de instalar), ejecuta:

```bash
cd ~/ecosistema

# Esto crea la vista que une usuarios de Moodle + ERP
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "CALL db_erp.sp_create_global_users_view();"
```

**Verificar que se creó:**

```bash
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "SELECT COUNT(*) as total_usuarios FROM db_erp.view_global_users;"
```

Debería mostrar un número > 2 (admin de Moodle + usuarios del ERP).

---

## Paso 7: Conectar ToolJet a MariaDB

Abre `http://erp.sana.es` (o `http://tu_vps_ip:3000` si testeas localmente)

### 7.1 → Setup inicial de ToolJet

- Crear cuenta admin
- Email: `admin@sana.es`
- Contraseña: (elige una fuerte)

### 7.2 → Añadir Data Source: MariaDB

En ToolJet:
1. **Data sources** (menú izquierdo)
2. **Create new → MariaDB/MySQL**
3. Completar:

| Campo | Valor |
|---|---|
| **Name** | `MariaDB_ERP` |
| **Host** | `mariadb` (nombre del contenedor en la red interna) |
| **Port** | `3306` |
| **Database** | `db_erp` |
| **Username** | `erp_user` |
| **Password** | (la de `ERP_DB_PASSWORD` en `.env`) |
| **SSL mode** | `disable` (interna, no necesaria) |

4. **Test connection** → Debe dar OK
5. **Save**

### 7.3 → Crear una Query de Prueba

En ToolJet, crear una nueva **App**:
1. **Database queries → MariaDB_ERP → New query**
2. Query:
```sql
SELECT id, code, name, is_active 
FROM sys_companies
WHERE is_active = 1;
```
3. Run → Debe mostrar SANA + GP Producciones

---

## Paso 8: Validar el stack

### 8.1 → Health checks automáticos

```bash
cd ~/ecosistema

# Ver estado de todos los contenedores
docker compose ps

# Ver logs sin pausarse (Ctrl+C para salir)
docker compose logs --tail=50 -f
```

### 8.2 → Tests de conectividad básica

```bash
# Verificar que MariaDB responde
docker exec mariadb mariadb -u root -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "SELECT 1 AS ok;"

# Verificar que Redis responde
docker exec redis redis-cli ping

# Verificar que PostgreSQL de ToolJet responde
docker exec tooljet-db psql -U tooljet -d tooljet_production \
  -c "SELECT version();"
```

### 8.3 → Verificar membresía de red

```bash
# Todos deben estar en la red "ecosistema_net"
docker network inspect ecosistema_net

# Deberías ver 7 contenedores conectados
```

### 8.4 → Test de aplicaciones

```bash
# Desde el VPS mismo:
curl -I http://localhost/             # NPM → WordPress
curl -I http://localhost:81/          # Panel NPM admin
curl -I http://localhost:3000/        # ToolJet (puerto aleatorio interno)
curl -I http://localhost:8080/        # Moodle (puerto interno)
```

---

## 🐛 Troubleshooting

### ❌ Error: "docker: command not found"

```bash
# Docker no está instalado
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

### ❌ Error: "Mariadb exited with code 127"

```bash
# MariaDB se crasha por falta de RAM
# Verificar swap:
swapon --show
free -h

# Si no hay swap, crear uno (ver Paso 1.3)
```

### ❌ Error: "Moodle stuck in install loop"

```bash
# Los logs dicen "ERROR: Exception - Table X doesn't exist"
# Esperar 5 más minutos (Moodle es lento)
docker compose logs moodle | tail -50

# Si persiste, reiniciar solo Moodle:
docker compose restart moodle
docker compose logs -f moodle
```

### ❌ Error: "ToolJet: JavaScript heap out of memory"

```bash
# Node.js necesita más RAM
# En docker-compose.yml, cambiar en 'tooljet':
NODE_OPTIONS: "--max-old-space-size=1024"  # Aumentar a 1024

# Y aumentar el deploy.resources.limits.memory a 1536M

# Luego:
docker compose up -d tooljet
```

### ❌ Error: "NPM: port 81 already in use"

```bash
# Cambiar en docker-compose.yml:
ports:
  - "8081:81"  # Usar 8081 en lugar de 81

docker compose up -d npm
# Acceder a http://tu_ip:8081
```

### ❌ Error: "PostgreSQL connection refused"

```bash
# tooljet-db no está listo todavía
# Esperar más tiempo:
docker compose logs tooljet-db

# Si dice "ERROR: could not... listen", puerto en uso:
docker compose down tooljet-db
docker compose up -d tooljet-db
```

### ❌ WordPress no ve Redis

```bash
# Instalar plugin en WordPress UI:
# Plugins → Add New → buscar "Redis Object Cache"
# Install + Activate

# Verificar en Settings → Redis Object Cache
```

### ❌ Moodle no puede conectarse a BD

```bash
# Verificar credenciales en .env y docker-compose.yml
grep MOODLE_DB_PASSWORD .env

# Revisar logs:
docker compose logs moodle | grep -i "database\|mysql\|connect"

# Testear credenciales manualmente:
docker exec -it mariadb mariadb -u moodle_user -p'MoodleDbSecur3Pass2026!' \
  -h mariadb \
  -e "USE db_learning; SHOW TABLES; LIMIT 1;"
```

### ❌ "No space left on device"

```bash
# Disco lleno
df -h /

# Si docker_data/ está muy grande, hace backup y limpia:
du -sh docker_data/*
docker system prune -a  # ⚠️ Remove all unused containers/images
```

---

## 📚 Comandos útiles

### Gestión básica

```bash
# Ver estado
docker compose ps

# Ver logs
docker compose logs -f [servicio]
  # [servicio] = npm, mariadb, wordpress, moodle, tooljet, etc.

# Restartear un servicio
docker compose restart [servicio]

# Pausar/reanudar sin perder datos
docker compose pause
docker compose unpause

# Parar (sin borrar volúmenes)
docker compose down

# Parar Y borrar TODO (⚠️ se pierden datos)
docker compose down -v
```

### Acceso a BDs

```bash
# MariaDB:
docker exec -i mariadb mariadb -u root -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "SHOW DATABASES;"

# PostgreSQL (ToolJet):
docker exec -i tooljet-db psql -U tooljet -d tooljet_production \
  -c "SELECT datname FROM pg_database;"

# Redis:
docker exec -i redis redis-cli DBSIZE
```

### Backups

```bash
cd ~/ecosistema

# Backup completo
docker compose pause
tar czf backup_$(date +%F_%H%M%S).tar.gz docker_data/ .env init.sql docker-compose.yml
docker compose unpause

# Listar backups
ls -lh backup_*.tar.gz

# Restaurar (⚠️ requiere `docker compose down -v` primero)
docker compose down -v
tar xzf backup_2025-02-14_123456.tar.gz
docker compose up -d
```

### Monitoreo de recursos

```bash
# Stats en vivo
docker stats

# Uso de disco
du -sh docker_data/*/
echo "Total:" && du -sh docker_data/

# Memoria y CPU de cada servicio
docker compose ps --quiet | xargs -I {} docker stats {}
```

---

## 🔐 Seguridad Post-Deploy

### Cambiar contraseñas de producción

```bash
# En .env, cambiar TODAS las contraseñas:
nano .env

# Luego actualizar en MariaDB:
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  << 'EOF'
ALTER USER 'wp_user'@'%' IDENTIFIED BY 'nueva_contraseña';
ALTER USER 'moodle_user'@'%' IDENTIFIED BY 'nueva_contraseña';
ALTER USER 'erp_user'@'%' IDENTIFIED BY 'nueva_contraseña';
FLUSH PRIVILEGES;
EOF
```

### Generar claves seguras para ToolJet

```bash
# Regenerar estas claves antes de producción:
openssl rand -hex 32  # → TOOLJET_LOCKBOX_KEY (guardar en .env)
openssl rand -hex 64  # → TOOLJET_SECRET_KEY (guardar en .env)

# Reiniciar ToolJet:
docker compose up -d tooljet
```

### Firewall (UFW en Ubuntu)

```bash
# Permitir solo lo necesario
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP NPM
sudo ufw allow 443/tcp   # HTTPS NPM
sudo ufw allow 81/tcp    # Admin NPM (restringir a tu IP en producción)
sudo ufw enable

# Ver reglas:
sudo ufw status numbered
```

---

## 📞 Soporte & Next Steps

### Si algo falla:
1. Revisa los logs: `docker compose logs -f [servicio]`
2. Consulta la sección **Troubleshooting** arriba
3. Verifica que el swap está activo: `free -h`
4. Reinicia el stack: `docker compose restart`

### Próxims tareas opcionales:

- [ ] Configurar backup automático (cron + rsync)
- [ ] Añadir monitoreo (Prometheus + Grafana)
- [ ] Securizar NPM con contraseña + 2FA
- [ ] Crear usuarios de prueba en cada platform
- [ ] Setup de CI/CD para deploy automático
- [ ] Configurar alertas de disco/RAM

---

**¡Ya está todo listo! 🚀 Ejecuta el paso 3 (setup.sh) para comenzar.**
