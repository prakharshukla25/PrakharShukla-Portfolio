FROM nginx/nginx-unprivileged:1.30.6-alpine

LABEL org.opencontainers.image.title="Prakhar Shukla portfolio" \
      org.opencontainers.image.description="Static DevOps portfolio served by unprivileged NGINX"

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY _site/ /usr/share/nginx/html/

USER 101:101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --spider http://127.0.0.1:8080/healthz || exit 1
