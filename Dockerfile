# Build static frontend files
FROM node:24-alpine AS builder

WORKDIR /app

ENV NODE_ENV=production

ARG VITE_API_BASE_URL=/api

COPY frontend .

RUN corepack enable && \
    CI=true pnpm install && \
    VITE_API_BASE_URL=$VITE_API_BASE_URL pnpm build

# Build backend image that also serves frontend (stored in `/app/frontend-dist`)
FROM python:3.14-alpine3.22
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN rm -rf /var/cache/apk/*

COPY backend /app
WORKDIR /app

# -- Install dependencies:
RUN addgroup --system bracket && \
    adduser --system bracket --ingroup bracket && \
    chown -R bracket:bracket /app
USER bracket

RUN uv sync --no-dev --locked

COPY --from=builder /app/dist /app/frontend-dist

# On Heroku the run command from heroku.yml (binds to $PORT) takes precedence over CMD.
# For local docker-compose runs we keep a sane default here.
ENV PORT=8400
EXPOSE 8400

CMD ["sh", "-c", "uv run --no-dev --locked -- gunicorn -k uvicorn.workers.UvicornWorker bracket.app:app --bind 0.0.0.0:${PORT} --workers 1 --forwarded-allow-ips='*'"]
