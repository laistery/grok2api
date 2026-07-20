FROM golang:1.21-alpine
WORKDIR /app
RUN apk update && apk add --no-cache git ca-certificates tzdata

# 克隆到子目录，避免路径错乱
RUN git clone https://github.com/chenyme/grok2api.git api
WORKDIR /app/api

# 编译
RUN go mod tidy
RUN go build -o /app/grok2api ./cmd/main.go

# 切回运行目录
WORKDIR /app
EXPOSE 8000
CMD ["/app/grok2api"]
