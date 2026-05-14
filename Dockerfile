FROM python:3.11-slim

WORKDIR /app

# Install system dependencies for Oracle Instant Client
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget unzip && \
    apt-get install -y --no-install-recommends libaio1t64 || \
    apt-get install -y --no-install-recommends libaio1 && \
    rm -rf /var/lib/apt/lists/*

# Create libaio.so.1 symlink (Bookworm ships libaio.so.1t64)
RUN if [ -f /usr/lib/x86_64-linux-gnu/libaio.so.1t64 ] && [ ! -e /usr/lib/x86_64-linux-gnu/libaio.so.1 ]; then \
        ln -sf /usr/lib/x86_64-linux-gnu/libaio.so.1t64 /usr/lib/x86_64-linux-gnu/libaio.so.1; \
    fi && ldconfig

# Download and install Oracle Instant Client 23
RUN mkdir -p /opt/oracle && \
    wget -q https://download.oracle.com/otn_software/linux/instantclient/2380000/instantclient-basiclite-linux.x64-23.8.0.25.04.zip \
         -O /tmp/instantclient.zip && \
    unzip -q /tmp/instantclient.zip -d /opt/oracle && \
    rm /tmp/instantclient.zip && \
    ln -sf /opt/oracle/instantclient_* /opt/oracle/instantclient && \
    echo /opt/oracle/instantclient > /etc/ld.so.conf.d/oracle-instantclient.conf && \
    ldconfig && \
    apt-get purge -y wget unzip && \
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
