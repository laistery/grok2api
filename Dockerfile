# 统一编译环境
FROM node:22-alpine AS builder

# 预装go环境
RUN apk add --no-cache go git

WORKDIR /build
# 直接拉取完整官方源码，彻底脱离你本地/fork仓库文件缺失问题
RUN git clone https://github.com/chenyme/grok2api.git .

# 编译前端
WORKDIR /build/frontend
RUN npm install -g pnpm@9
RUN pnpm install
RUN pnpm run build

# 编译后端
WORKDIR /build
RUN go env -w GOPROXY=https://goproxy.cn,direct
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -o grok2api ./cmd/main.go

# 运行镜像
FROM alpine:3.19
WORKDIR /app
RUN apk add --no-cache ca-certificates tzdata
COPY --from=builder /build/grok2api /app/
COPY --from=builder /build/frontend/dist /app/frontend/dist

EXPOSE 8000
CMD ["/app/grok2api"]
