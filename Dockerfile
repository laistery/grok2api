FROM golang:1.21-alpine

WORKDIR /app

# 安装基础依赖
RUN apk update && apk add --no-cache git ca-certificates tzdata

# 直接拉取源码
RUN git clone https://github.com/chenyme/grok2api.git .

# 下载依赖+编译
RUN go mod tidy && go build -o grok2api ./cmd/main.go

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["/app/grok2api"]
