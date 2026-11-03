FROM node:24-bookworm-slim
WORKDIR /app
COPY --chown=node:node package.json ./
COPY --chown=node:node shared ./shared
COPY --chown=node:node src/repositories/catalog_repository.js ./src/repositories/catalog_repository.js
COPY --chown=node:node src/utils/http.js ./src/utils/http.js
RUN mkdir -p /app/data && chown node:node /app/data
USER node
ENV HOST=0.0.0.0 PORT=3000 DB_PATH=/app/data/shared-demo.db
EXPOSE 3000
CMD ["node", "shared/server.js"]
