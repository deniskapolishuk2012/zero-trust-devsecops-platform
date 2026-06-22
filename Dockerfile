# Multi-stage build — final image carries no compiler/package manager, runs as a
# fixed non-root UID (matches runAsUser: 65532 in demo/workload-identity-demo/deployment.yaml
# and Kyverno's restricted Pod Security policy), and has a read-only root filesystem.
FROM python:3.14-alpine AS builder

WORKDIR /build
COPY app/requirements.txt .
RUN pip install --no-cache-dir --target=/build/deps -r requirements.txt

FROM python:3.14-alpine

RUN adduser -u 65532 -D -s /sbin/nologin appuser

WORKDIR /app
COPY --from=builder /build/deps /app/deps
COPY app/main.py .

ENV PYTHONPATH=/app/deps \
    PYTHONUNBUFFERED=1

USER 65532
EXPOSE 8080

ENTRYPOINT ["python", "-m", "gunicorn", "--bind=0.0.0.0:8080", "--workers=2", "main:app"]
