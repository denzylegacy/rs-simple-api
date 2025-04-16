FROM messense/rust-musl-cross:x86_64-musl as chef
ENV SQLX_OFFLINE=true
RUN cargo install cargo-chef
WORKDIR /rs-simple-api

FROM chef AS planner
# Copy source code from previous stage
COPY . .
# Generate info for caching dependencies
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /rs-simple-api/recipe.json recipe.json
# Build & cache dependencies
RUN cargo chef cook --release --target x86_64-unknown-linux-musl --recipe-path recipe.json
# Copy source code from previous stage
COPY . .
# Build application
RUN cargo build --release --target x86_64-unknown-linux-musl

# Use alpine instead of scratch for better compatibility
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /rs-simple-api/target/x86_64-unknown-linux-musl/release/rs-simple-api /app/rs-simple-api
# Explicitly copy migrations folder to the correct path
COPY --from=builder /rs-simple-api/migrations /app/migrations
# Create a symbolic link for ./migrations to point to /app/migrations
RUN ln -s /app/migrations /app/./migrations
ENTRYPOINT ["/app/rs-simple-api"]
EXPOSE 3000