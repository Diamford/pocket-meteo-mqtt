FROM golang:1.27.4-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /collector .

FROM alpine:3.23
RUN apk add --no-cache ca-certificates \
    && addgroup -S collector \
    && adduser -S -G collector collector
COPY --from=build /collector /usr/local/bin/collector
USER collector
ENTRYPOINT ["/usr/local/bin/collector"]
