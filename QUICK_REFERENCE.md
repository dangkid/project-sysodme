# ⚡ QUICK REFERENCE — Comandos Frecuentes

**Guardar este archivo en tu servidor para referencia rápida.**

---

## 🚀 PRIMERAS VECES (Setup Inicial)

### Setup completo (primero en el VPS)

```bash
cd ~/ecosistema
chmod +x setup.sh
./setup.sh
nano .env          # Cambiar contraseñas
docker compose up -d
sleep 60           # Esperar a que levanten
docker compose logs -f  # Monitorizar
```

### Tests rápidos post-deploy

```bash
# ¿Está todo arriba?
docker compose ps

# ¿Mariadb responde?
docker exec mariadb mariadb -u root -pROOT_PASSWORD -e "SELECT 1;"

# ¿WordPress se ve?
curl -I http://localhost/ 

# ¿NPM admin accesible?
curl -I http://localhost:81/

# ¿ToolJet started?
docker compose logs tooljet | tail -10
```

---

## 📊 MONITOREO & LOGS

### Ver estado
```bash
docker compose ps                    # Estado de cada contenedor
docker compose ps --format table     # Formato tabular
docker image ls | grep -E "nginx|mariadb|wordpress"  # Imágenes en uso
```

### Ver logs
```bash
docker compose logs                  # Últimos logs
docker compose logs -f               # Logs en vivo (Ctrl+C para salir)
docker compose logs --tail=50 -f     # Últimos 50 + en vivo
docker compose logs [servicio]       # Solo un servicio
  # [servicio]: npm, mariadb, wordpress, moodle, redis, tooljet, tooljet-db
```

### Filtrar errores
```bash
docker compose logs | grep -i error
docker compose logs | grep -i exception
docker compose logs moodle | grep -i "fatal"
```

### Stats en vivo
```bash
docker stats                         # CPU, RAM, net I/O de cada contenedor
docker stats --no-stream             # Sin actualización
```

---

## 🛠️ CONTROL DE SERVICIOS

### Manage single service
```bash
docker compose up -d [servicio]      # Levantar solo uno
docker compose restart [servicio]    # Restartear uno
docker compose stop [servicio]       # Parar solo uno
docker compose start [servicio]      # Startear uno parado
docker compose remove [servicio]     # Borrar contenedor (no volumen)
```

### Manage all services
```bash
docker compose up -d                 # Levantar todo
docker compose restart               # Restartear todo
docker compose pause                 # Pausar (congelar procesos)
docker compose unpause               # Reanudar
docker compose down                  # Parar sin borrar volúmenes
docker compose down -v               # 🔴 PELIGRO: Parar Y eliminar TODO (se pierden datos)
```

---

## 🗄️ BASE DE DATOS

### Acceso a MariaDB
```bash
# Conectar a la BD
docker exec -it mariadb mariadb -u root -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)"

# Sin interactividad (útil en scripts)
docker exec -i mariadb mariadb -u root -p"PASSWORD" -e "SHOW DATABASES;"

# Ejecutar script SQL desde archivo
docker exec -i mariadb mariadb -u root -pPASSWORD < script.sql

# Dump/Backup de una BD
docker exec -i mariadb mysqldump -u root -pPASSWORD db_erp > backup_erp.sql

# Restore desde dump
docker exec -i mariadb mariadb -u root -pPASSWORD db_erp < backup_erp.sql
```

### Consultas comunes

```bash
# Ver todas las BDs
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD \
  -e "SHOW DATABASES;"

# Ver usuarios
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD \
  -e "SELECT User, Host FROM mysql.user;"

# Ver tablas de db_erp
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD \
  -e "USE db_erp; SHOW TABLES;"

# Contar registros en tabla
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD \
  -e "SELECT COUNT(*) FROM db_erp.sys_companies;"

# Ver estructura de tabla
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD \
  -e "DESCRIBE db_erp.sys_companies;"
```

### Crear la Vista global (después de Moodle install)

```bash
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "CALL db_erp.sp_create_global_users_view();"

# Verificar
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "SELECT * FROM db_erp.view_global_users LIMIT 5;"
```

### Cambiar contraseña de usuario BD

```bash
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD << 'EOF'
ALTER USER 'wp_user'@'%' IDENTIFIED BY 'nueva_password';
ALTER USER 'moodle_user'@'%' IDENTIFIED BY 'nueva_password';
FLUSH PRIVILEGES;
EOF
```

---

## 📦 APLICACIONES

### WordPress

```bash
# Plugins (CLI)
docker exec -it wordpress wp plugin list --allow-root
docker exec -it wordpress wp plugin install redis-cache --allow-root --activate

# Ver configuración
docker exec -it wordpress wp option get siteurl --allow-root

# Theme list
docker exec -it wordpress wp theme list --allow-root
```

### Moodle

```bash
# Ver logs de install
docker compose logs moodle | grep -i "install"

# Ejecutar maintenance
docker exec -it moodle /bitnami/scripts/moodle/run.sh

# Ver versión instalada
docker exec -it moodle php -r "echo phpversion();"
```

### ToolJet

```bash
# Ver variables de entorno
docker exec tooljet env | grep TOOLJET

# Ver logs
docker compose logs -f tooljet

# Regenerar claves (⚠️ hace logout a todos)
# 1. Edita .env con:
#    TOOLJET_LOCKBOX_KEY=<nuevo_valor>
#    TOOLJET_SECRET_KEY=<nuevo_valor>
# 2. docker compose up -d tooljet
```

---

## 🔌 REDES & CONECTIVIDAD

### Inspeccionar red interna

```bash
# Ver contenedores en red
docker network inspect ecosistema_net

# Testear DNS interno (nombre de contenedor)
docker exec wordpress ping -c 3 mariadb
docker exec tooljet ping -c 3 redis
docker exec moodle ping -c 3 mariadb

# Testear puertos
docker exec wordpress nc -zv mariadb 3306   # MariaDB
docker exec wordpress curl -I http://npm:81  # NPM admin
```

### Ports externos

```bash
# Ver qué puertos expone NPM
docker port npm

# Cambiar puerto externo (en docker-compose.yml)
ports:
  - "8080:80"     # HTTP en puerto 8080
  - "8443:443"    # HTTPS en puerto 8443
  - "8081:81"     # Admin en puerto 8081

# Luego:
docker compose up -d npm
```

---

## 💾 BACKUPS & RESTORE

### Backup completo

```bash
cd ~/ecosistema

# Pausar los servicios (importante para integridad)
docker compose pause

# Hacer tarball
tar czf backup_$(date +%F_%H%M%S).tar.gz docker_data/ .env init.sql docker-compose.yml

# Reanudar
docker compose unpause

# Listar backups
ls -lh backup_*.tar.gz
```

### Backup solo BD

```bash
# MariaDB (todas las BDs)
docker exec -i mariadb mysqldump -u root -pROOT_PASSWORD \
  --all-databases > full_backup.sql

# Una BD específica
docker exec -i mariadb mysqldump -u root -pROOT_PASSWORD db_erp \
  > db_erp_backup.sql
```

### Restore desde backup

```bash
# ⚠️ DESTRUCTIVO: primero parar
docker compose down -v

# Extraer backup
tar xzf backup_2025-02-14_120000.tar.gz

# Levantar
docker compose up -d

# Esperar a MariaDB
sleep 30

# Si hiciste dump SQL, restaurar:
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD < full_backup.sql
```

### rsync a otro servidor

```bash
# Push a servidor backup
rsync -avz --progress --delete \
  ~/ecosistema/docker_data/ \
  usuario@backup-server:/backups/ecosistema/docker_data/

# Pull desde servidor backup
rsync -avz --progress --delete \
  usuario@backup-server:/backups/ecosistema/docker_data/ \
  ~/ecosistema/docker_data/
```

---

## 🔍 TROUBLESHOOTING RÁPIDO

### "Service X está stuck/restarting"

```bash
# Ver por qué falla
docker compose logs -f [servicio]

# Restart clean
docker compose stop [servicio]
docker compose rm [servicio]    # Elimina contenedor
docker compose up -d [servicio] # Levanta nuevo
```

### "Out of Memory / OOMKilled"

```bash
# Ver cuál consume más
docker stats

# Aumentar limites en docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 2G    # Aumentar
    reservations:
      memory: 1G

docker compose up -d
```

### "Port already in use"

```bash
# Ver qué usa el puerto
sudo lsof -i :80     # Puerto 80
sudo lsof -i :3306   # Puerto 3306

# O en docker
docker ps -a | grep :80

# Cambiar puerto en docker-compose.yml y restart
```

### "DNS/Network issues"

```bash
# Verificar que están en la misma red
docker network inspect ecosistema_net

# Testear ping interno
docker exec wordpress ping mariadb

# Recrear red
docker network rm ecosistema_net
docker compose up -d    # Crea red de nuevo
```

### "Mariadb can't start (port 3306 in use)"

```bash
# Buscar proceso usando el puerto
sudo netstat -tulpn | grep 3306

# Si hay otro mysql, matar proceso
sudo pkill -f "mysql|mariadb"

# O cambiar puerto interno de compose
# En mariadb:
#   environment:
#     MYSQL_PORT: 3307
# En otros servicios:
#   MOODLE_DATABASE_HOST: mariadb:3307
```

---

## 🛡️ SEGURIDAD

### Cambiar contraseña admin NPM

```bash
# Acceder a http://tu_ip:81 → Settings → Users → edit
# O vía SQL:
docker exec -i mariadb mariadb -u root -pROOT_PASSWORD << 'EOF'
USE npm_dev;
UPDATE users SET password = MD5('nueva_contraseña') WHERE username = 'admin';
EOF
```

### Regenerar claves ToolJet

```bash
# Generar nuevas claves
openssl rand -hex 32  # Copiar → TOOLJET_LOCKBOX_KEY
openssl rand -hex 64  # Copiar → TOOLJET_SECRET_KEY

# Actualizar .env
nano .env

# Reiniciar
docker compose up -d tooljet
```

### Firewall (UFW)

```bash
# Permitir solo SSH, HTTP, HTTPS
sudo ufw default deny incoming
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
# Optional: admin NPM solo desde tu IP
sudo ufw allow from 192.168.1.100 to any port 81
sudo ufw enable
```

---

## 🧹 LIMPIEZA

### Eliminar contenedores e imágenes sin usar

```bash
# Listar dangling images
docker image ls -f "dangling=true"

# Limpiar (⚠️ no afecta volúmenes)
docker system prune -a --volumes

# Solo imágenes
docker image prune -a

# Solo contenedores
docker container prune
```

### Liberar espacio en disco

```bash
# Ver tamaño de cada volumen
du -sh ~/ecosistema/docker_data/*/

# Total
du -sh ~/ecosistema/docker_data/

# Si está muy grande, hacer backup, parar y limpiar
docker compose down
docker image prune -a
docker volume prune
```

---

## 📚 REFERENCIAS

### Variables de entorno por servicio

**Moodle (PHP):**
```
PHP_MEMORY_LIMIT=256M
PHP_UPLOAD_MAX_FILESIZE=100M
PHP_MAX_EXECUTION_TIME=300
PHP_MAX_INPUT_VARS=5000
```

**ToolJet (Node.js):**
```
NODE_OPTIONS=--max-old-space-size=768
```

**MariaDB (InnoDB):**
```
--innodb-buffer-pool-size=512M
--innodb-log-file-size=48M
--max-connections=100
```

### Archivos importantes

- `.env` — Contraseñas y config (NO al Git)
- `docker-compose.yml` — Stack definition
- `init.sql` — SQL initialization
- `docker_data/` — Volúmenes persistentes

---

## 🆘 Últimos Recursos

Si nada funciona:

1. Mira logs: `docker compose logs | tail -100`
2. Verifica RAM: `free -h`
3. Verifica disco: `df -h`
4. Restartea todo: `docker compose restart`
5. Si persiste: `docker compose down && docker compose up -d`

**¡Good luck! 🚀**
