FROM python:3.11-slim

WORKDIR /app

# Install system dependencies and Oracle Instant Client (thick mode for NNE)
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip \
        $(apt-cache show libaio1t64 >/dev/null 2>&1 && echo libaio1t64 || echo libaio1) && \
    mkdir -p /opt/oracle && \
    wget -q https://download.oracle.com/otn_software/linux/instantclient/2380000/instantclient-basiclite-linux.x64-23.8.0.25.04.zip \
         -O /tmp/instantclient.zip && \
    unzip -q /tmp/instantclient.zip -d /opt/oracle && \
    rm /tmp/instantclient.zip && \
    ln -s /opt/oracle/instantclient_* /opt/oracle/instantclient && \
    apt-get purge -y wget unzip && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

ENV ORACLE_CLIENT_DIR=/opt/oracle/instantclient
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient:${LD_LIBRARY_PATH}

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Copy application code
COPY . .

# Set bundle path for Linux
ENV BUNDLE_PATH=/app/bundle_2026-Mar-01/MENU/analyzers/SQL
ENV DEMO_MODE=false
ENV PORT=8000

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

EXPOSE 8000

CMD ["./entrypoint.sh"]
