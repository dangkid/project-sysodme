# ============================================================
#  ETAPA 1: Build
#  Compila tu React/Vue/Svelte app con Node.js
# ============================================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copiar package.json y instalar dependencias
COPY package*.json ./
RUN npm install

# Copiar TODO el código fuente
COPY . .

# Compilar
RUN npm run build

# ============================================================
#  ETAPA 2: Runtime
#  Nginx sirve los archivos compilados
# ============================================================
FROM nginx:alpine

# Copiar archivos compilados desde el builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copiar configuración de Nginx
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost/health || exit 1

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
