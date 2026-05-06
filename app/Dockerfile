# syntax=docker/dockerfile:1.7

FROM golang:1.22-alpine AS build
WORKDIR /src

# Cache module downloads.
COPY go.mod ./
RUN go mod download || true

COPY . .
# go mod tidy ensures go.sum is present and reproducible without committing it.
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w" \
    -o /out/ecom-api ./

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /out/ecom-api /app/ecom-api
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/ecom-api"]
