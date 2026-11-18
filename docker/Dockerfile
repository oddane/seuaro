# Seuaro node image: the pinned upstream binaries built by scripts/build.sh,
# plus the Seuaro entrypoint. Build context is the repository root:
#   docker build -f docker/Dockerfile -t seuaro/node:local .
# The base must match the glibc of the machine that built bin/ (CI: ubuntu-24.04).
FROM ubuntu:24.04

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates python3 python3-yaml libpq5 curl \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 10001 --home-dir /opt/sui --shell /usr/sbin/nologin sui \
 && mkdir -p /opt/sui/key-pairs /opt/sui/db /opt/sui/checkpoints /ceremony /users \
 && chown -R sui:sui /opt/sui /ceremony /users

COPY bin/sui bin/sui-node bin/sui-faucet bin/seuaro-verify /usr/local/bin/
COPY docker/entrypoint.py /usr/local/bin/seuaro-entrypoint
COPY UPSTREAM.lock /opt/sui/UPSTREAM.lock

# ADR-0008: every Seuaro process runs Sui mainnet's protocol feature set.
ENV SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE=mainnet \
    RUST_LOG=info,sui_core=info,consensus_core=info

USER sui
WORKDIR /opt/sui
ENTRYPOINT ["python3", "-I", "/usr/local/bin/seuaro-entrypoint"]
CMD ["help"]
