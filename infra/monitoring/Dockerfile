FROM node:20-alpine
WORKDIR /app
RUN npm install -g pnpm@latest

# Use host registry by default, can be overridden with build-arg
ARG NPM_REGISTRY=https://registry.npmjs.org
ENV NPM_CONFIG_REGISTRY=${NPM_REGISTRY}

# Copy monitoring service files
COPY package.json ./package.json
COPY server.js ./server.js
COPY dashboard.html ./dashboard.html

# Install only production deps
RUN pnpm install --prod --frozen-lockfile || pnpm install --prod

EXPOSE 3001
CMD ["node", "server.js"]
