# 前端构建阶段
FROM node:20-alpine AS frontend-builder
WORKDIR /src/frontend

# 修复缓存id格式，加cacheKey前缀
RUN --mount=type=cache,id=cacheKey-grok2api-pnpm,target=/pnpm/store \
    corepack enable pnpm && corepack use pnpm@latest

COPY frontend/package*.json ./
RUN --mount=type=cache,id=cacheKey-grok2api-pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

COPY frontend/ .
RUN --mount=type=cache,id=cacheKey-grok2api-tsc,target=/src/frontend/.cache,sharing=locked \
    pnpm run build

# Go后端编译阶段
FROM golang:1.22-alpine AS backend-builder
WORKDIR /src

ENV CGO_ENABLED=0
ENV GOOS=linux

# 修复go mod缓存格式
RUN --mount=type=cache,id=cacheKey-grok2api-go-mod,target=/go/pkg/mod,sharing=locked

COPY go.mod go.sum ./
RUN --mount=type=cache,id=cacheKey-grok2api-go-mod,target=/go/pkg/mod,sharing=locked \
    go mod download

COPY . .
COPY --from=frontend-builder /src/frontend/dist ./frontend/dist

RUN go build -o grok2api ./cmd/main.go

# 最终运行镜像
FROM alpine:3.19
WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata
COPY --from=backend-builder /src/grok2api /app/grok2api

EXPOSE 8000
CMD ["/app/grok2api"]
