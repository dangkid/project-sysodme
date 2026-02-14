import { useState } from 'react'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <div className="container">
      <header className="header">
        <nav className="navbar">
          <div className="logo">🏥 SANA</div>
          <ul className="nav-links">
            <li><a href="#inicio">Inicio</a></li>
            <li><a href="#servicios">Servicios</a></li>
            <li><a href="#academy">Academy</a></li>
            <li><a href="#contacto">Contacto</a></li>
          </ul>
        </nav>
      </header>

      <main>
        {/* Hero Section */}
        <section id="inicio" className="hero">
          <div className="hero-content">
            <h1>Ecosistema Empresarial SANA</h1>
            <p>Soluciones integradas de formación, gestión y clínica</p>
            <button className="cta-button">Comenzar ahora</button>
          </div>
        </section>

        {/* Services Section */}
        <section id="servicios" className="services">
          <h2>Nuestros Servicios</h2>
          <div className="services-grid">
            <div className="service-card">
              <h3>📚 SANA Academy</h3>
              <p>Plataforma de formación con Moodle integrado</p>
            </div>
            <div className="service-card">
              <h3>🏥 Gestión Clínica</h3>
              <p>Historiales médicos y gestión de pacientes</p>
            </div>
            <div className="service-card">
              <h3>⚙️ ERP Empresarial</h3>
              <p>Sistema de gestión integral con ToolJet</p>
            </div>
          </div>
        </section>

        {/* Academy Section */}
        <section id="academy" className="academy">
          <h2>Accede a SANA Academy</h2>
          <a href="https://academy.sana.es" className="academy-button">
            Ir a Academy →
          </a>
        </section>

        {/* Contact Section */}
        <section id="contacto" className="contact">
          <h2>Contacto</h2>
          <p>Email: info@sana.es</p>
          <p>Teléfono: +34 999 999 999</p>
        </section>
      </main>

      <footer className="footer">
        <p>&copy; 2026 SANA. Todos los derechos reservados.</p>
      </footer>

      {/* Test Counter (puedes eliminarlo) */}
      <div style={{ position: 'fixed', bottom: 20, right: 20 }}>
        <button onClick={() => setCount(count + 1)}>
          Count: {count}
        </button>
      </div>
    </div>
  )
}

export default App
