# Railway deployment wrapper for grok2api v3.0.6.
# Pin the upstream image so deployments are reproducible.
FROM ghcr.io/chenyme/grok2api:v3.0.6

COPY --chmod=0755 docker/entrypoint.sh /usr/local/bin/grok2api-railway-entrypoint

# The upstream image healthcheck is fixed to port 8000, while Railway injects
# a dynamic PORT. Railway's service healthcheck will use /healthz instead.
HEALTHCHECK NONE

ENTRYPOINT ["/usr/local/bin/grok2api-railway-entrypoint"]
CMD ["/app/grok2api", "--config", "/app/config.yaml"]
