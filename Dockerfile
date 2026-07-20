# 前端构建阶段 完全原版
FROM node:20-alpine AS frontend-builder
WORKDIR /src/frontend

RUN corepack enable pnpm && corepack use pnpm@latest

COPY frontend/package*.json ./
RUN pnpm install --frozen-lockfile

COPY frontend/ .
RUN pnpm run build

# 后端构建阶段 改这里：不用本地go.sum，容器内自动生成
FROM golang:1.22-alpine AS backend-builder
WORKDIR /src

ENV CGO_ENABLED=0
ENV GOOS=linux

# 只拷贝go.mod，放弃拷贝go.sum
COPY go.mod ./
# 自动整理依赖生成go.sum并下载
RUN go mod tidy

# 拷贝全部源码
COPY . .
# 合并编译好的前端静态文件
COPY --from=frontend-builder /src/frontend/dist ./frontend/dist

# 编译主程序
RUN go build -o grok2api ./cmd/main.go

# 最终运行镜像 原版不变
FROM alpine:3.19
WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata
COPY --from=backend-builder /src/grok2api /app/grok2api

EXPOSE 8000
CMD ["/app/grok2api"]
