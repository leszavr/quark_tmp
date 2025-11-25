/** @type {import('next').NextConfig} */
const nextConfig = {
  // Используем Babel компилятор вместо SWC из-за проблем с минификацией template strings
  compiler: {
    // Отключаем SWC компилятор полностью
  },
  swcMinify: false,
  
  // Добавляем webpack конфигурацию для отладки
  webpack: (config, { isServer }) => {
    // Отключаем минификацию для отладки
    if (!isServer) {
      config.optimization.minimize = false;
    }
    
    // Добавляем поддержку устаревших API Shadow DOM для совместимости
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        "child_process": false,
        "fs": false,
        "net": false,
        "tls": false,
        "crypto": false,
      };
    }
    
    return config;
  },
  
  // Настройки для лучшей работы с Google Fonts
  experimental: {
    // optimizePackageImports: ["@chakra-ui/react"], // удалено, не поддерживается в Next.js 13
  },
  
  // Настройки сети
  images: {
    domains: ['localhost'],
    dangerouslyAllowSVG: true,
    contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com https://fonts.googleapis.com data:; connect-src 'self'; media-src 'self';",
  },
  
  // Headers для лучшей загрузки шрифтов
  async headers() {
    return [
      {
        source: "/fonts/:path*",
        headers: [
          {
            key: "Cache-Control",
            value: "public, max-age=31536000, immutable",
          },
        ],
      },
      {
        source: '/:path*',
        headers: [
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' https://fonts.gstatic.com https://fonts.googleapis.com data:; connect-src 'self'; media-src 'self';"
          },
        ],
      },
    ];
  },
  
  // Отключаем React Dev Overlay в production для избежания ошибок с Shadow DOM
  productionBrowserSourceMaps: false,
};

module.exports = nextConfig;