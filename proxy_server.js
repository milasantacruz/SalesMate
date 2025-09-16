const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 8080;

// Configurar CORS para permitir Flutter Web dinámicamente
app.use(cors({
  origin: function (origin, callback) {
    // Permitir requests sin origin (ej: mobile apps) y localhost con cualquier puerto
    if (!origin || origin.startsWith('http://localhost:') || origin.startsWith('http://127.0.0.1:')) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Cookie', 'Set-Cookie'],
  credentials: true // CRÍTICO: Permitir cookies
}));

// Proxy para el servidor Odoo
const odooProxy = createProxyMiddleware({
  target: 'https://odooconsultores-mtfood-staging-23633807.dev.odoo.com',
  changeOrigin: true,
  secure: true,
  logLevel: 'debug',
  cookieDomainRewrite: 'localhost',
  cookiePathRewrite: '/',
  onError: (err, req, res) => {
    console.error('Proxy Error:', err);
    res.status(500).json({ error: 'Proxy Error', details: err.message });
  },
  onProxyReq: (proxyReq, req, res) => {
    console.log(`Proxying request: ${req.method} ${req.url}`);
    
    // Log cookies enviadas para debug
    if (req.headers.cookie) {
      console.log('🍪 Cookies en request:', req.headers.cookie);
    }
  },
  onProxyRes: (proxyRes, req, res) => {
    // CORS headers compatibles con credentials - Puerto dinámico de Flutter
    const origin = req.headers.origin || 'http://localhost:50167';
    proxyRes.headers['Access-Control-Allow-Origin'] = origin;
    proxyRes.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
    proxyRes.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With, Cookie, Set-Cookie';
    proxyRes.headers['Access-Control-Allow-Credentials'] = 'true';
    proxyRes.headers['Access-Control-Expose-Headers'] = 'Set-Cookie';
    
    console.log(`Response from Odoo: ${proxyRes.statusCode}`);
    
    // Log y modificar cookies para debug
    if (proxyRes.headers['set-cookie']) {
      console.log('🍪 Cookies originales:', proxyRes.headers['set-cookie']);
      
      // Modificar cookies para que funcionen con localhost
      const modifiedCookies = proxyRes.headers['set-cookie'].map(cookie => {
        // Remover Secure flag para localhost y modificar dominio
        return cookie
          .replace(/; Secure/g, '')
          .replace(/; Domain=[^;]+/g, '')
          .replace(/; SameSite=Lax/g, '; SameSite=None');
      });
      
      proxyRes.headers['set-cookie'] = modifiedCookies;
      console.log('🍪 Cookies modificadas:', modifiedCookies);
    }
  }
});

// Usar el proxy para todas las rutas
app.use('/', odooProxy);

app.listen(PORT, () => {
  console.log(`🚀 CORS Proxy Server running on http://localhost:${PORT}`);
  console.log(`📡 Proxying to: https://odooconsultores-mtfood-staging-23633807.dev.odoo.com`);
  console.log(`🔧 CORS enabled with credentials support`);
  console.log(`🍪 Cookie debugging enabled`);
});
