# ========== 只构建前端静态资源 ==========
FROM node:22-alpine AS frontend-build
WORKDIR /work
# 只复制前端目录
COPY frontend ./frontend
WORKDIR /work/frontend
RUN npm install -g pnpm@9
RUN pnpm install
RUN pnpm run build

# ========== 单独构建后端 Go 程序 ==========
FROM golang:1.22-alpine AS backend-build
WORKDIR /work
# 只复制后端核心文件
COPY go.mod ./
COPY cmd ./cmd
COPY internal ./internal
COPY pkg ./pkg
COPY config ./config
# 下载依赖编译
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o grok2api ./cmd/main.go

# ========== 最终运行镜像 ==========
FROM alpine:3.19
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
# 拷贝编译好的后端程序
COPY --from=backend-build /work/grok2api ./
# 拷贝编译好的前端静态页面
COPY --from=frontend-build /work/frontend/dist ./frontend/dist

EXPOSE 8000
CMD ["/app/grok2api"]
