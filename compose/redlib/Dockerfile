FROM rust:bookworm as builder
WORKDIR /app
RUN git clone --depth=1 https://github.com/redlib-org/redlib.git .
RUN cargo build --release

FROM gcr.io/distroless/cc-debian12
COPY --from=builder /app/target/release/redlib /
ENTRYPOINT ["/redlib"]