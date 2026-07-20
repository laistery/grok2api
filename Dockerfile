# 前端构建 使用高版本Node适配pnpm
FROM node:22-alpine AS fe
WORKDIR /app
COPY . .
WORKDIR /app/frontend
# 固定安装兼容低Node的旧版pnpm，不自动拉最新
RUN npm install -g pnpm@9
RUN pnpm install --frozen-lockfile
RUN pnpm run build

# 后端编译
FROM golang:1.22-alpine AS be
WORKDIR /app
COPY . .
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod tidy
# 合并前端打包产物
COPY --from=fe /app/frontend/dist /app/frontend/dist
RUN CGO_ENABLED=0 GOOS=linux go build -o grok2api ./cmd/main.go

# 运行容器
FROM alpine:3.19
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
COPY --from=be /app/grok2api ./
EXPOSE 8000
CMD ["/app/grok2api"]
