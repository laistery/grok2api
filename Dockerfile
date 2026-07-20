# 前端构建
FROM node:20-alpine AS fe
WORKDIR /app
COPY . .
WORKDIR /app/frontend
RUN corepack enable pnpm && corepack use pnpm@latest
RUN pnpm install --frozen-lockfile
RUN pnpm run build

# 后端编译
FROM golang:1.22-alpine AS be
WORKDIR /app
# 一次性拷贝全部项目源码
COPY . .
# 写入国内代理加速
RUN go env -w GOPROXY=https://goproxy.cn,direct
# 自动生成依赖文件并下载
RUN go mod tidy
# 把编译好的前端静态文件复制进来
COPY --from=fe /app/frontend/dist /app/frontend/dist
# 编译程序
RUN CGO_ENABLED=0 GOOS=linux go build -o grok2api ./cmd/main.go

# 运行镜像
FROM alpine:3.19
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
COPY --from=be /app/grok2api ./
EXPOSE 8000
CMD ["/app/grok2api"]
