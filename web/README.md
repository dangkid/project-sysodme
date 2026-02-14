# 🌐 SANA Web - Landing Page (React SPA)

Este es el código frontend de la landing page de SANA. Utiliza **React 18 + Vite**.

---

## 📋 Estructura

```
web/
├── src/
│   ├── main.jsx          # Entry point de React
│   ├── App.jsx           # Componente principal
│   ├── App.css           # Estilos de App
│   └── index.css         # Estilos globales
├── index.html            # HTML template
├── package.json          # Dependencias
├── vite.config.js        # Configuración de Vite
├── Dockerfile            # Multi-stage build para producción
├── nginx.conf            # Config de Nginx para SPA
└── .gitignore
```

---

## 🚀 Desarrollo Local

### 1. Instalar dependencias

```bash
cd web
npm install
```

### 2. Runear servidor de desarrollo

```bash
npm run dev
```

Abre `http://localhost:5173` en tu navegador. Los cambios se reflajan en vivo.

### 3. Compilar para producción

```bash
npm run build
```

Genera archivos en `dist/` listos para Nginx.

---

## 🐳 Despliegue con Docker

El `Dockerfile` usa **multi-stage build**:

1. **Stage 1**: Node.js compila tu código (`npm run build`)
2. **Stage 2**: Nginx sirve los archivos compilados

### En tu VPS (desde carpeta raíz del proyecto):

```bash
cd ~/project-sysodme
docker compose build web
docker compose up -d web
```

El contenedor estará disponible en `http://localhost:3000`.

---

## 🎨 Personalización

### Cambiar contenido

Edita `src/App.jsx` directamente. Los archivos estáticos (imágenes, documentos) van en `public/`.

### Cambiar estilos

`src/App.css` contiene todos los estilos. Usa las variables CSS definidas en `:root` para mantener consistencia.

### Cambiar rutas (React Router)

```jsx
import { BrowserRouter, Routes, Route } from 'react-router-dom'

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
      </Routes>
    </BrowserRouter>
  )
}
```

**IMPORTANTE**: El `nginx.conf` ya está configurado para redirigir URLs no reconocidas a `index.html`, de modo que React Router funciona correctamente.

---

## 📦 Agregar librerías

```bash
npm install react-icons       # Iconos
npm install axios              # HTTP client
npm install zustand            # State management (alternativa a Redux)
npm install tailwindcss        # Utility CSS framework
```

---

## 🔒 Build optimizado

El `vite.config.js` ya tiene:

- ✅ Terser minification (reduce JS)
- ✅ Source maps desactivados (producción)
- ✅ Console logs removidos

El resultado típico es un bundle de **~50-100 KB** (gzipped).

---

## 🧪 Deploy a VPS automatizado

Desde tu máquina local:

```bash
git add .
git commit -m "Update web app"
git push
```

Desde tu VPS:

```bash
cd ~/project-sysodme
git pull
docker compose build web --no-cache
docker compose up -d web
docker compose logs -f web    # Ver logs
```

---

## 📚 Documentación oficial

- **React**: https://react.dev
- **Vite**: https://vitejs.dev
- **React Router**: https://reactrouter.com

---

## ❓ FAQ

**P: ¿Cómo agrego un formulario de contacto?**

R: Utiliza un servicio como Formspree, EmailJS o crea un backend Node.js.

**P: ¿Puedo usar Vue o Svelte en lugar de React?**

R: Sí. Edita `package.json` y `vite.config.js` (`@vitejs/plugin-vue` o `@vitejs/plugin-svelte`).

**P: ¿Cómo conecto a un API?**

R: Usa `fetch()` o `axios`:

```jsx
useEffect(() => {
  fetch('https://api.example.com/data')
    .then(res => res.json())
    .then(data => setData(data))
}, [])
```

**P: ¿Cómo hago SEO?**

R: Para SEO avanzado, usa **Next.js** (versión full-stack de React con SSR). Por ahora, edita `index.html` con `<meta>` tags correctos.

---

**Último update**: 14 de febrero de 2026
