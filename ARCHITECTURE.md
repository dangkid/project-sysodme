# 🏗️ ARCHITECTURE & DESIGN — Documentación Técnica

**Para DevOps, Cloud Architects y SysAdmins que necesiten entender el diseño.**

---

## 📐 Diagrama de la Arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                       VPS (Ubuntu 24.04)                            │
│                   4 vCPU | 8 GB RAM | 75 GB NVMe                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                   Docker Network                             │  │
│  │              internal_network (bridge)                       │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │                                                              │  │
│  │  ┌─────────────────────────────────────────────────────┐    │  │
│  │  │  [1] NGINX PROXY MANAGER                           │    │  │
│  │  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │    │  │
│  │  │  Ports: 80 (HTTP), 443 (HTTPS), 81 (Admin Panel)  │    │  │
│  │  │  Memory: 256 MB | CPU: 0.5                        │    │  │
│  │  │  Role: Proxy inverso, SSL/TLS termination         │    │  │
│  │  │                                                     │    │  │
│  │  │  Routes:                                           │    │  │
│  │  │    www.sana.es       →  wordpress:80             │    │  │
│  │  │    academy.sana.es   →  moodle:8080              │    │  │
│  │  │    erp.sana.es       →  tooljet:3000             │    │  │
│  │  └─────────────────────────────────────────────────────┘    │  │
│  │            ↓ (interna, sin exposición pública)               │  │
│  │  ┌─────────────────────────────────────────────────────┐    │  │
│  │  │  [7] MARIADB 10.11 (Central Database)              │    │  │
│  │  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │    │  │
│  │  │  Port: 3306 (interno a red)                        │    │  │
│  │  │  Memory: 1536 MB | CPU: 1.0                       │    │  │
│  │  │  Storage: ./docker_data/mariadb (persistent)      │    │  │
│  │  │                                                     │    │  │
│  │  │  Esquemas:                                         │    │  │
│  │  │  ├─ db_landing   (WordPress)                      │    │  │
│  │  │  ├─ db_learning  (Moodle)                         │    │  │
│  │  │  └─ db_erp       (ERP & Gestión)                  │    │  │
│  │  │                                                     │    │  │
│  │  │  Config InnoDB:                                   │    │  │
│  │  │  • buffer_pool: 512 MB                            │    │  │
│  │  │  • log_file_size: 48 MB                           │    │  │
│  │  │  • max_connections: 100                           │    │  │
│  │  │  • query_cache: 32 MB                             │    │  │
│  │  └─────────────────────────────────────────────────────┘    │  │
│  │                      ↑  ↓ (SQL queries)                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │  [2] WP      │  │  [3] MOODLE  │  │  [5] TOOLJET │       │  │
│  │  │  WordPress   │  │  (Bitnami)   │  │  (Node.js)   │       │  │
│  │  │              │  │              │  │              │       │  │
│  │  │ 512 MB RAM   │  │ 1536 MB RAM  │  │ 1024 MB RAM  │       │  │
│  │  │ 0.75 CPU     │  │ 1.0 CPU      │  │ 1.0 CPU      │       │  │
│  │  │              │  │              │  │              │       │  │
│  │  │ Port: 80     │  │ Port: 8080   │  │ Port: 3000   │       │  │
│  │  │ (interna)    │  │ (interna)    │  │ (interna)    │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  │         ↓                ↓                   ↓                 │  │
│  │  ┌──────────────────┐          ┌──────────────────┐          │  │
│  │  │  [6] REDIS 7     │          │  [4] POSTGRESQL  │          │  │
│  │  │  (Cache)         │          │  (ToolJet DB)    │          │  │
│  │  │                  │          │                  │          │  │
│  │  │ 128 MB RAM       │          │ 256 MB RAM       │          │  │
│  │  │ 0.25 CPU         │          │ 0.25 CPU         │          │  │
│  │  │                  │          │                  │          │  │
│  │  │ Port: 6379       │          │ Port: 5432       │          │  │
│  │  │ (interna)        │          │ (interna)        │          │  │
│  │  └──────────────────┘          └──────────────────┘          │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Decisiones de Arquitectura

### 1. **ToolJet vs Appsmith**

| Criterio | ToolJet CE | Appsmith |
|:---|:---|:---|
| Runtime | Node.js | Java (JVM) |
| BD Interna | PostgreSQL | MongoDB |
| RAM Mínimo | ~1.2 GB | ~2.5 GB |
| Licencia | MIT (Open Source) | Libre pero + features en cloud |
| **Ganador** | **ToolJet** ✅ | Appsmith ❌ (demasiado pesado) |

**Decisión:** Con 8 GB de RAM y este stack, **ToolJet es la única opción viable**.

### 2. **Nginx Proxy Manager vs Traefik vs HAProxy**

| Criterio | NPM | Traefik | HAProxy |
|:---|:---|:---|:---|
| UI Web | ✅ Excelente | ❌ Mínima | ❌ Ninguna |
| SSL Let's Encrypt | ✅ Automático | ✅ Automático | ⚠️ Manual |
| Curva aprendizaje | ✅ Muy baja | ⚠️ Media | ❌ Alta |
| RAM | 256 MB | 100 MB | 50 MB |
| Docker 🔧 | Perfecto para ASIR | Mejor para K8s | Enterprise |

**Decisión:** **NPM** para facilitar la vida a un SysAdmin sin experiencia en DevOps.

### 3. **Red Docker: Bridge Custom**

```yaml
networks:
  internal_network:
    driver: bridge
    name: ecosistema_net
```

**Por qué:**
- ✅ DNS automático entre contenedores (resuelve por nombre)
- ✅ Aislamiento del host
- ✅ No requiere exposición de puertos internos
- ✅ Fácil de debuggear con `docker exec`

---

## 💾 Modelo de Datos — db_erp

### Tabla Central: `sys_companies`

```sql
CREATE TABLE sys_companies (
  id            INT PRIMARY KEY AUTO_INCREMENT,
  code          VARCHAR(20) UNIQUE,          -- SANA, GPP, NUEVA
  name          VARCHAR(150),
  tax_id        VARCHAR(20),                 -- NIF/CIF
  sector        VARCHAR(100),
  is_active     TINYINT(1),
  created_at    TIMESTAMP,
  updated_at    TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**Multi-tenancy simple:**
- Cada tabla de negocio tiene `company_id FOREIGN KEY → sys_companies.id`
- Queries filtran por `WHERE company_id = 1` (SANA)

### Tabla: `erp_users_extended`

```sql
CREATE TABLE erp_users_extended (
  id           INT PRIMARY KEY AUTO_INCREMENT,
  company_id   INT FOREIGN KEY,             -- Vinculado a empresa
  username     VARCHAR(100) UNIQUE,
  email        VARCHAR(255),
  password_hash VARCHAR(255) COLLATE utf8mb4_unicode_ci,
  first_name   VARCHAR(100),
  last_name    VARCHAR(100),
  role         ENUM('admin','manager','employee','viewer'),
  is_active    TINYINT(1),
  created_at   TIMESTAMP,
  updated_at   TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

**Nota:** Usuarios de Moodle en `db_learning.mdl_user` (integrados vía VIEW).

### Vista: `view_global_users`

```sql
CREATE OR REPLACE VIEW view_global_users AS
SELECT
  CONCAT('moodle_', m.id) as global_id,
  'moodle' as source_system,
  m.id as source_id,
  m.username, m.email, m.firstname, m.lastname,
  -- ... resto de campos
FROM db_learning.mdl_user m
WHERE m.deleted = 0

UNION ALL

SELECT
  CONCAT('erp_', e.id) as global_id,
  'erp' as source_system,
  e.id as source_id,
  e.username, e.email, e.first_name, e.last_name,
  -- ... resto de campos
FROM db_erp.erp_users_extended e;
```

**Caso de uso:**
- ToolJet ejecuta: `SELECT * FROM view_global_users WHERE company_id = 1`
- Obtiene usuarios de BOTH Moodle y ERP en una sola query

---

## 📊 Allocación de Recursos

### RAM Total: 8 GB

```
Servicios:          5.248 GB (65.6%)
├─ Moodle:          1.536 GB (mayor consumer)
├─ MariaDB:         1.536 GB (segunda mayor)
├─ ToolJet:         1.024 GB (Node.js heap)
├─ WordPress:       0.512 GB
├─ NPM:             0.256 GB
├─ PostgreSQL:      0.256 GB
└─ Redis:           0.128 GB

SO & Buffer:        2.752 GB (34.4%)
├─ Kernel:          ~500 MB
├─ Caches:          ~1.5 GB
├─ Swap:            4.0 GB (en disco, emergencia)
```

### CPU Total: 4 vCPU

```
Asignados: 3.75 CPUs
├─ Moodle:     1.0 CPU
├─ MariaDB:    1.0 CPU
├─ ToolJet:    1.0 CPU
├─ WordPress:  0.75 CPU
└─ Otros:      0.0 CPUs (compartiben tiempo)

Disponible:   0.25 CPUs (overhead)
```

**Comportamiento:**
- Bajo carga normal: servicios usan 50% de su CPU assignada
- Pico de carga: pueden usar 100% (excepto limites del host)
- Si un servicio necesita más, reduce otro (edita docker-compose.yml)

---

## 🔄 Flujos de Datos Principales

### Flow 1: Usuario accede WordPress

```
[Navegador] (www.sana.es)
     ↓ HTTPS
[NPM - Puerto 443] (termina SSL)
     ↓ HTTP interno
[WordPress Port 80]
     ↓ (si falta cache)
[Redis Port 6379] (objeto cache)
     ↓ (si falta en BD)
[MariaDB Port 3306 - db_landing]
```

### Flow 2: Estudiante entra a Moodle

```
[Navegador] (academy.sana.es)
     ↓ HTTPS
[NPM - Puerto 443]
     ↓ HTTP interno
[Moodle Port 8080]
     ↓ (credentials)
[MariaDB Port 3306 - db_learning]
     ↓ respuesta
[Moodle] renderiza
```

### Flow 3: ToolJet consulta ERP

```
[ToolJet UI] (erp.sana.es)
[Node.js App - Port 3000]
     ↓ (SQL Query)
[MariaDB Port 3306 - db_erp]
     ↓ SELECT view_global_users
[UNION: mdl_user + erp_users_extended]
     ↓ JSON response
[ToolJet Dashboard]
```

---

## 🔐 Seguridad de Red

### Exposición al exterior:

```yaml
Puertos expuestos (solo NPM):
├─ 80/tcp   (HTTP)  → Redirige a 443
├─ 443/tcp  (HTTPS) → Termina SSL para todos
└─ 81/tcp   (Admin) → ⚠️ Restringir a IPs confiables

Puertos internos (NO se exponen):
├─ 3306     (MariaDB)
├─ 5432     (PostgreSQL)
├─ 6379     (Redis)
├─ 8080     (Moodle)
├─ 3000     (ToolJet)
└─ Otros...
```

### Estrategia de firewall recomendada:

```bash
# UFW en Ubuntu
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow from 192.168.1.0/24 to any port 81      # Solo desde red local
ufw default deny incoming
ufw default allow outgoing
```

---

## 🛠️ Persistencia & Volúmenes

### Volúmenes vs Bind Mounts

```yaml
# Todos usan Bind Mounts (./docker_data/X)
# Razón: facilita backup con tar/rsync para SysAdmin

volumes:
  - ./docker_data/wordpress:/var/www/html      # Archivos + uploads
  - ./docker_data/moodle:/bitnami/moodle        # Código + config
  - ./docker_data/moodledata:/bitnami/moodledata # Datos grandes
  - ./docker_data/mariadb:/var/lib/mysql        # BD completa
  - ./docker_data/redis:/data                   # Snapshots RDB
  - ./docker_data/tooljet-db:/var/lib/postgresql/data # PostgreSQL
  - ./docker_data/npm/data:/data                # Config NPM
  - ./docker_data/npm/letsencrypt:/etc/letsencrypt # Certs SSL
```

### Backup Strategy:

```bash
# Pause para integridad transaccional
docker compose pause

# Backup completo en una línea
tar czf backup_$(date +%F).tar.gz docker_data/

# Reanudar
docker compose unpause

# Resultado: archivo comprimido que contiene TODO
# Típicamente 2-5 GB (dependiendo de datos WordPress)
```

---

## 📈 Scaling Considerations (Futuro)

Si necesitas crecer desde este punto:

### Opción 1: Vertical (aumentar recursos)
```
Upgrade VPS:
  8 vCPU, 16 GB RAM, 150 GB NVMe
  → Simplemente aumenta limits en docker-compose.yml
  → Cero cambios de código
```

### Opción 2: Horizontal (múltiples servidores)
```
Servidor 1 (BD Central):
  ├─ MariaDB + Redis

Servidor 2 (Apps):
  ├─ WordPress
  ├─ Moodle
  └─ ToolJet

Requiere:
  • Cambiar MariaDB_HOST a IP servidor 1
  • Usar RabbitMQ/Redis para sesiones distribuidas
  • Load Balancer (Nginx/HAProxy)
```

### Opción 3: Kubernetes (Enterprise)
```
Reemigrarse a K8s sería:
  ✗ Overkill para 3 empresas
  ⚠️ Requeriría refactoring completo
  ✓ Pero posible después

Recomendación: Stick with Docker Compose hasta 50+ usuarios/empresa
```

---

## 🧪 Testing & Validation

### Healthchecks automáticos en compose:

```yaml
services:
  mariadb:
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s    # Espera antes de chequear
```

**Resultado:**
```bash
$ docker compose ps
NAME         STATUS
mariadb      Up 30s (health: starting)  # Arrancando
mariadb      Up 60s (health: healthy)   # ✓ Listo
```

---

## 🔍 Monitoreo Recomendado (Optional)

Aunque no incluído, puedes añadir:

```yaml
# prometheus + grafana (opcional, usa ~500 MB extra)
monitoring:
  image: prom/prometheus:latest
  image: grafana/grafana:latest
```

**Métricas importantes:**
- RAM por servicio
- CPU usage
- Disco disponible
- Conexiones BD activas
- Hits en cache Redis

---

## 📝 Resumen de Decisiones

| Decisión | Alternativa Rechazada | Razón |
|---|---|---|
| ToolJet | Appsmith | RAM (1G vs 2.5G) |
| NPM | Traefik | UI + facilidad ASIR |
| Bridge Network | Host Network | Seguridad + aislamiento |
| Bind mounts | Docker volumes | Facilita backups |
| Single MariaDB | Separate DBs | Simplifica: 1 BD con 3 esquemas |
| Redis Optional | Ignorarlo | Mejora perf. WordPress dramáticamente |

---

## 🎓 Para profundizar

- **Docker Compose:** https://docs.docker.com/compose
- **MariaDB 10.11:** https://dev.mysql.com/doc
- **Moodle Architecture:** https://docs.moodle.org
- **ToolJet Docs:** https://docs.tooljet.com

---

**Documento actualizado:** 14 de febrero de 2026  
**Versión:** 1.0 (Production Ready)
