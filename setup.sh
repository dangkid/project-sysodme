#!/bin/bash

################################################################################
#                                                                              #
#  ECOSISTEMA EMPRESARIAL UNIFICADO — Setup Automatizado v1.0                #
#  Prepara la estructura de volúmenes y valida el entorno                     #
#                                                                              #
#  Uso:  ./setup.sh                                                           #
#  Req:  Docker >= 24.0, Docker Compose >= 2.0, bash >= 4.0                  #
#                                                                              #
################################################################################

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIRED_FILES=(".env" "docker-compose.yml" "init.sql")
DOCKER_DATA_DIRS=(
  "npm/data"
  "npm/letsencrypt"
  "mariadb"
  "redis"
  "wordpress"
  "moodle"
  "moodledata"
  "tooljet-db"
)

################################################################################
#  Funciones auxiliares
################################################################################

print_header() {
  echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║ ECOSISTEMA EMPRESARIAL UNIFICADO — Setup Automatizado      ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_step() {
  echo -e "${BLUE}→${NC} $1"
}

print_ok() {
  echo -e "${GREEN}✓${NC} $1"
}

print_error() {
  echo -e "${RED}✗${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
  echo -e "${BLUE}ℹ${NC} $1"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    print_error "Comando no encontrado: $1"
    return 1
  fi
  return 0
}

################################################################################
#  Validaciones previas
################################################################################

validate_requirements() {
  print_step "Verificando requisitos..."
  
  # Docker
  if ! check_command docker; then
    print_error "Docker no está instalado"
    echo "    Instala con: curl -fsSL https://get.docker.com | sh"
    exit 1
  fi
  print_ok "Docker encontrado: $(docker --version)"
  
  # Docker Compose
  if ! check_command docker; then
    print_error "Docker Compose no está disponible"
    exit 1
  fi
  print_ok "Docker Compose encontrado: $(docker compose version | head -1)"
  
  # Docker daemon running
  if ! docker info &> /dev/null; then
    print_error "Docker daemon no está corriendo"
    echo "    En Linux: sudo systemctl start docker"
    echo "    En macOS: abre Docker Desktop"
    exit 1
  fi
  print_ok "Docker daemon está activo"
  
  # Bash version
  if (( BASH_VERSIONSINFO[0] < 4 )); then
    print_warning "Bash < 4.0 detectado. Algunos features pueden no funcionar."
  else
    print_ok "Bash >= 4.0: OK"
  fi
  
  echo ""
}

validate_files() {
  print_step "Validando archivos de configuración..."
  
  for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
      print_error "Archivo requerido no encontrado: $file"
      exit 1
    fi
    size=$(stat -f%z "$SCRIPT_DIR/$file" 2>/dev/null || stat -c%s "$SCRIPT_DIR/$file" 2>/dev/null)
    print_ok "$file ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "$size bytes"))"
  done
  
  echo ""
}

validate_env() {
  print_step "Validando variables de entorno en .env..."
  
  required_vars=(
    "DB_ROOT_PASSWORD"
    "WP_DB_PASSWORD"
    "MOODLE_DB_PASSWORD"
    "ERP_DB_PASSWORD"
    "MOODLE_ADMIN_PASSWORD"
    "TOOLJET_PG_PASSWORD"
  )
  
  for var in "${required_vars[@]}"; do
    if ! grep -q "^$var=" "$SCRIPT_DIR/.env"; then
      print_error "Variable requerida no encontrada en .env: $var"
      exit 1
    fi
    print_ok "$var está definida"
  done
  
  echo ""
}

################################################################################
#  Creación de estructura
################################################################################

create_directories() {
  print_step "Creando estructura de volúmenes..."
  
  mkdir -p "$SCRIPT_DIR/docker_data"
  
  for dir in "${DOCKER_DATA_DIRS[@]}"; do
    full_path="$SCRIPT_DIR/docker_data/$dir"
    mkdir -p "$full_path"
    print_ok "Creado: $dir"
  done
  
  # Directorios adicionales
  mkdir -p "$SCRIPT_DIR/backups"
  print_ok "Creado: backups/"
  
  echo ""
}

set_permissions() {
  print_step "Asignando permisos..."
  
  # Permisos estándar (755 dirs, 644 files)
  find "$SCRIPT_DIR/docker_data" -type d -exec chmod 755 {} \;
  find "$SCRIPT_DIR/docker_data" -type f -exec chmod 644 {} \;
  
  # Mariadb: necesita permisos específicos
  chmod 700 "$SCRIPT_DIR/docker_data/mariadb"
  
  # NPM: permisos para config
  chmod 755 "$SCRIPT_DIR/docker_data/npm"
  chmod 755 "$SCRIPT_DIR/docker_data/npm/data"
  chmod 755 "$SCRIPT_DIR/docker_data/npm/letsencrypt"
  
  # Moodle: permisos de escritura
  chmod 750 "$SCRIPT_DIR/docker_data/moodle"
  chmod 750 "$SCRIPT_DIR/docker_data/moodledata"
  
  print_ok "Permisos configurados"
  echo ""
}

################################################################################
#  Validación del disco
################################################################################

check_disk_space() {
  print_step "Verificando espacio disponible..."
  
  available_kb=$(df "$SCRIPT_DIR" | tail -1 | awk '{print $4}')
  available_gb=$((available_kb / 1024 / 1024))
  
  # Requerimos al menos 50 GB disponibles
  if [ "$available_gb" -lt 50 ]; then
    print_warning "Espacio disponible: $available_gb GB (recomendado >= 50 GB)"
    echo "    El despliegue podría tener problemas de almacenamiento"
  else
    print_ok "Espacio disponible: $available_gb GB"
  fi
  
  echo ""
}

check_memory() {
  print_step "Verificando RAM disponible..."
  
  # Obtener memoria total
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    available_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    total_mem_kb=$(($(sysctl -n hw.memsize) / 1024))
    available_mem_kb=$(vm_stat | grep "Pages free" | awk '{print $3 * 4}')
  fi
  
  total_mem_gb=$((total_mem_kb / 1024 / 1024))
  available_mem_gb=$((available_mem_kb / 1024 / 1024))
  
  if [ "$total_mem_gb" -lt 8 ]; then
    print_error "RAM insuficiente: $total_mem_gb GB (se requieren 8 GB)"
    exit 1
  fi
  
  print_ok "RAM total: $total_mem_gb GB"
  print_ok "RAM disponible: $available_mem_gb GB"
  
  if [ "$available_mem_gb" -lt 4 ]; then
    print_warning "Poca RAM disponible. Cierra aplicaciones innecesarias."
  fi
  
  # Verificar swap (Linux)
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    swap_kb=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    if [ "$swap_kb" -eq 0 ]; then
      print_warning "No hay swap configurado. Se recomienda crear uno (ver README.md)"
    else
      swap_gb=$((swap_kb / 1024 / 1024))
      print_ok "Swap disponible: $swap_gb GB"
    fi
  fi
  
  echo ""
}

################################################################################
#  Validación de docker-compose.yml
################################################################################

validate_compose() {
  print_step "Validando sintaxis de docker-compose.yml..."
  
  if ! docker compose -f "$SCRIPT_DIR/docker-compose.yml" config > /dev/null 2>&1; then
    print_error "docker-compose.yml tiene errores de sintaxis"
    docker compose -f "$SCRIPT_DIR/docker-compose.yml" config 2>&1 | head -20
    exit 1
  fi
  
  print_ok "Sintaxis válida"
  
  # Contar servicios
  num_services=$(docker compose -f "$SCRIPT_DIR/docker-compose.yml" config \
    | grep -E '^\s{2}[a-z-]+:$' | wc -l | tr -d ' ')
  print_ok "Número de servicios: $num_services"
  
  echo ""
}

################################################################################
#  Create network
################################################################################

create_network() {
  print_step "Creando/verificando red Docker..."
  
  if docker network ls | grep -q "ecosistema_net"; then
    print_ok "Red 'ecosistema_net' ya existe"
  else
    if docker network create \
      --driver bridge \
      --label "project=ecosistema" \
      ecosistema_net > /dev/null 2>&1; then
      print_ok "Red 'ecosistema_net' creada"
    else
      print_warning "Red 'ecosistema_net' ya existe o no se pudo crear (continuando...)"
    fi
  fi
  
  echo ""
}

################################################################################
#  Resumen final
################################################################################

print_summary() {
  echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║                    ✓ SETUP COMPLETADO                      ║${NC}"
  echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  
  echo -e "${BLUE}📂 Estructura creada:${NC}"
  echo "   $SCRIPT_DIR"
  echo "   ├── .env (variables de entorno)"
  echo "   ├── docker-compose.yml"
  echo "   ├── init.sql"
  echo "   ├── docker_data/ (volúmenes persistentes)"
  echo "   └── backups/ (para tus backups)"
  echo ""
  
  echo -e "${BLUE}📋 Próximos pasos:${NC}"
  echo "   1. Edita .env y cambia TODAS las contraseñas:"
  echo "      nano $SCRIPT_DIR/.env"
  echo ""
  echo "   2. Levanta el stack:"
  echo "      cd $SCRIPT_DIR"
  echo "      docker compose up -d"
  echo ""
  echo "   3. Monitoriza los logs:"
  echo "      docker compose logs -f"
  echo ""
  echo "   4. Cuando Moodle termine (2-5 min), crea la vista de usuarios:"
  echo "      docker exec -i mariadb mariadb -u root \\"
  echo "        -p\"\$(grep DB_ROOT_PASSWORD .env | cut -d= -f2)\" \\"
  echo "        -e \"CALL db_erp.sp_create_global_users_view();\""
  echo ""
  echo "   5. Accede a Nginx Proxy Manager:"
  echo "      http://tu_vps_ip:81"
  echo "      Usuario: admin@example.com"
  echo "      Contraseña: changeme"
  echo ""
  
  echo -e "${BLUE}📖 Más detalles en: README.md${NC}"
  echo ""
}

################################################################################
#  MAIN
################################################################################

main() {
  print_header
  
  # Ejecutar validaciones y setup
  validate_requirements
  validate_files
  validate_env
  validate_compose
  check_disk_space
  check_memory
  create_directories
  set_permissions
  create_network
  
  # Resumen
  print_summary
}

# Execute main
main "$@"
