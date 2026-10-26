# Etapa 1: build (entorno virtual con dependencias)
FROM python:3.12-slim AS build
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Etapa 2: runtime
FROM python:3.12-slim
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1
WORKDIR /app
RUN useradd --system --uid 1001 app
COPY --from=build /opt/venv /opt/venv
COPY --chown=app:app main.py .
USER app
EXPOSE 3003
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request as u; u.urlopen('http://localhost:3003/health')"
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3003"]
