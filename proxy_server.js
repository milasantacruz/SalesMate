const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
const PORT = 8080;

// Configurar CORS para permitir todos los orígenes y cookies
app.use(cors({
  origin: true, // Permitir origen específico para cookies
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Cookie', 'Set-Cookie'],
  credentials: true // CRÍTICO: Permitir cookies
}));

// Proxy para el servidor Odoo
const odooProxy = createProxyMiddleware({
  target: 'https://odooconsultores-mtfood-staging-22669119.dev.odoo.com',
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
    // Agregar headers CORS al request
    proxyReq.setHeader('Access-Control-Allow-Origin', '*');
  },
  onProxyRes: (proxyRes, req, res) => {
    // Agregar headers CORS a la respuesta
    proxyRes.headers['Access-Control-Allow-Origin'] = '*';
    proxyRes.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
    proxyRes.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization, X-Requested-With';
    console.log(`Response from Odoo: ${proxyRes.statusCode}`);
  }
});

// Usar el proxy para todas las rutas
app.use('/', odooProxy);

app.listen(PORT, () => {
  console.log(`🚀 CORS Proxy Server running on http://localhost:${PORT}`);
  console.log(`📡 Proxying to: http://testdocker.odooconsultores.cl:14014`);
  console.log(`🔧 CORS enabled for all origins`);
});
