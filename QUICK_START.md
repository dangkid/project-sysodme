# 🚀 INSTRUCCIONES RÁPIDAS PARA ASIR (Paso a Paso)

**Si eres ASIR y solo quieres que funcione, sigue esto exactamente en tu VPS.**

---

## 📍 PASO 1: Conectar al VPS

```bash
ssh usuario@tu_vps_ip
```

---

## 📍 PASO 2: Descargar el proyecto

### Opción A: Git (si lo subiste a un repositorio)
```bash
cd ~
git clone https://tu_repositorio.git
cd proyecto-sysodme
```

### Opción B: SCP desde tu máquina (recomendado si no usa Git)

**En tu máquina local (no en VPS):**
```bash
cd /ruta/a/los/archivos  # Dónde están .env, docker-compose.yml, etc
scp -r .env docker-compose.yml init.sql .gitignore README.md setup.sh usuario@tu_vps_ip:~/ecosistema
```

**Luego en VPS:**
```bash
cd ~/ecosistema
ls -la
# Debe mostrar: .env, docker-compose.yml, init.sql, etc.
```

---

## 📍 PASO 3: Preparar el servidor (10 minutos)

### 3a) Crear swap (OBLIGATORIO en 8 GB)
```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

**Verificar:**
```bash
free -h
# Debe mostrar 4G de Swap
```

### 3b) Abrir límites de archivos
```bash
sudo bash -c 'echo "* soft nofile 65536" >> /etc/security/limits.conf'
sudo bash -c 'echo "* hard nofile 65536" >> /etc/security/limits.conf'
```

---

## 📍 PASO 4: Cambiar contraseñas en .env

**⚠️ CRÍTICO: Cambiar TODAS las contraseñas**

```bash
cd ~/ecosistema
nano .env
```

Cambiar estas líneas (la contraseña que quieras, pero que sea fuerte):

```
DB_ROOT_PASSWORD=TuContraseña123Fuerte!
WP_DB_PASSWORD=OtraContraseña456Fuerte!
MOODLE_DB_PASSWORD=MasContraseñas789Fuerte!
ERP_DB_PASSWORD=YOtraMasContraseña012Fuerte!
```

**Guardar: Ctrl+O → Enter → Ctrl+X**

---

## 📍 PASO 5: Ejecutar el script de setup

```bash
cd ~/ecosistema
chmod +x setup.sh
./setup.sh
```

**Espera a que termine (debe mostrar "✓ SETUP COMPLETADO")**

---

## 📍 PASO 6: Levantar Docker (el momento de verdad)

```bash
cd ~/ecosistema
docker compose up -d
```

**Espera 5 segundos, luego verifica:**

```bash
docker compose ps
```

**Debes ver 7 contenedores, todos con STATUS "Up X seconds"**

---

## 📍 PASO 7: Esperar a que arranque Moodle (5-10 minutos)

```bash
docker compose logs -f moodle
```

**Déjalo correr. Cuando veas algo como:**
```
Moodle db setup completed
[Web Server] Starting Apache...
[Apache] Started.
```

**Presiona Ctrl+C y continúa.**

---

## 📍 PASO 8: Crear la Vista de usuarios (después de Moodle)

```bash
cd ~/ecosistema

docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "CALL db_erp.sp_create_global_users_view();"
```

**Debe mostrar:**
```
resultado
Vista view_global_users creada/actualizada correctamente.
```

---

## 📍 PASO 9: Acceder a Nginx Proxy Manager (configurar dominios)

**En tu máquina local, abre el navegador:**

```
http://tu_vps_ip:81
```

**Login:**
- Email: `admin@example.com`
- Contraseña: `changeme`

**INMEDIATO: Cambiar contraseña**
- Settings → Users → Click en admin → Change password → Save

---

## 📍 PASO 10: Crear 3 Proxy Hosts

En NPM, ir a **Proxy Hosts → Add Proxy Host** (3 veces):

### 1️⃣ WordPress (Landing)

```
Domain Names:    www.sana.es (o tu dominio)
Scheme:          http
Forward Hostname: wordpress
Forward Port:    80
SSL:             Let's Encrypt (o Self-Signed si no tienes dominio)
```

**Save**

### 2️⃣ Moodle (Academy)

```
Domain Names:    academy.sana.es
Scheme:          http
Forward Hostname: moodle
Forward Port:    8080
Websockets:      ✓ ON
SSL:             Let's Encrypt (o Self-Signed)
```

**Save**

### 3️⃣ ToolJet (ERP)

```
Domain Names:    erp.sana.es
Scheme:          http
Forward Hostname: tooljet
Forward Port:    3000
Websockets:      ✓ ON  (muy importante)
SSL:             Let's Encrypt (o Self-Signed)
```

**Save**

---

## 📍 PASO 11: Testear acceso

**Si NO tienes dominio, en tu máquina local edita /etc/hosts:**

```bash
# En Windows (C:\Windows\System32\drivers\etc\hosts):
# En Linux/Mac (/etc/hosts):
tu_vps_ip  www.sana.es
tu_vps_ip  academy.sana.es
tu_vps_ip  erp.sana.es
```

**Abre en navegador:**

- `http://www.sana.es` → Debería mostrar WordPress
- `http://academy.sana.es` → Debería mostrar Moodle (login admin/Adm1nM00dle2026!)
- `http://erp.sana.es` → Debería mostrar ToolJet

---

## 📍 PASO 12: Conectar ToolJet a MariaDB

**En ToolJet (erp.sana.es):**

1. **Crear cuenta admin (si no la hay)**
   - Email: admin@sana.es
   - Contraseña: (la que quieras)

2. **Data Sources** (menú izquierdo)

3. **Create New → MariaDB/MySQL**

4. Rellenar:
   ```
   Name:     MariaDB_ERP
   Host:     mariadb
   Port:     3306
   Database: db_erp
   Username: erp_user
   Password: (la de ERP_DB_PASSWORD en .env)
   ```

5. **Test Connection** → Debe decir OK

6. **Save**

---

## 📍 PASO 13: Verificar que todo funciona

### Verificación rápida:

```bash
# Estado de contenedores
docker compose ps

# Mariadb responde
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "SELECT version();"

# Vista de usuarios existe
docker exec -i mariadb mariadb -u root \
  -p"$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)" \
  -e "SELECT COUNT(*) as usuarios FROM db_erp.view_global_users;"
```

---

## ✅ ¡LISTO!

Si llegaste hasta aquí sin errores grandes, **tienes un ecosistema empresarial completo corriendo en 8 GB de RAM.**

### Ahora puedes:

- **WordPress:** Instalar plugins, crear contenido
- **Moodle:** Crear cursos y usuarios
- **ToolJet:** Diseñar dashboards, conectar a MariaDB

---

## 🆘 Si algo explota

### "Un servicio no levanta"

```bash
docker compose logs [servicio] | tail -50
# [servicio] = npm, mariadb, wordpress, moodle, redis, tooljet, tooljet-db
```

### "Mariadb dice 'port 3306 in use'"

```bash
docker compose down
sleep 5
docker compose up -d
```

### "ToolJet se queja de memoria"

```bash
# En docker-compose.yml, cambiar en 'tooljet':
NODE_OPTIONS: "--max-old-space-size=1024"
# Y en deploy.resources.limits.memory: 1536M

docker compose up -d tooljet
```

### "Moodle hace 5 minutos que levanta y sigue"

Es normal, Moodle tarda. Espera 10 minutos.

```bash
docker compose logs moodle | tail -20
```

Si no ves errores fatales (ERROR: Exception), déjalo.

---

## 📞 Comandos útiles (Guarda estos)

```bash
# Ver todo en vivo
docker compose logs -f

# Parar todo (sin perder datos)
docker compose down

# Levantar todo
docker compose up -d

# Restartear un servicio
docker compose restart [servicio]

# Backup completo (desde ~/ecosistema)
docker compose pause && tar czf backup_$(date +%F).tar.gz docker_data/ && docker compose unpause
```

---

**¡ÉXITO! 🎉**

Tu ecosistema está listo. Ahora administra cada app según necesites.
