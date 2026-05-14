# Deploying Oracle EBS Support Agent on Render

## Prerequisites

- GitHub repo: https://github.com/hellou2xai/ccoracleebs
- A Render account (https://render.com)
- Oracle DB accessible over the internet
- Your local hosts file entry (hostname -> IP mapping) for the Oracle DB

## Step 1: Create a New Web Service on Render

1. Log in to https://dashboard.render.com
2. Click **New** -> **Web Service**
3. Connect your GitHub account if not already connected
4. Select the repository: `hellou2xai/ccoracleebs`
5. Render will auto-detect the `Dockerfile` — no build command changes needed
6. Choose a plan (Starter or higher recommended)
7. Set the region closest to your Oracle DB for lower latency

## Step 2: Configure Environment Variables

In the Render dashboard, go to **Environment** and add these variables:

### Oracle Database (Required for live DB mode)

| Variable | Description | Example |
|----------|-------------|---------|
| `ORACLE_HOST` | The hostname from your local hosts file | `apps.example.com` |
| `ORACLE_HOST_IP` | The actual IP address it maps to | `192.168.1.100` |
| `ORACLE_PORT` | Oracle listener port | `1521` |
| `ORACLE_SID` | Oracle System Identifier | `EBSDB` |
| `ORACLE_SERVICE_NAME` | Oracle service name | `EBSDB` |
| `ORACLE_USER` | Database username | `apps` |
| `ORACLE_PASSWORD` | Database password | *(your password)* |

**Why ORACLE_HOST_IP?**
Your Oracle DB hostname resolves via your local machine's hosts file. Render containers don't have that entry. The `entrypoint.sh` script injects `ORACLE_HOST_IP -> ORACLE_HOST` into the container's `/etc/hosts` at startup, replicating your local setup.

### Anthropic API (Required)

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key (starts with `sk-ant-`) |

### JIRA Integration (Optional)

| Variable | Description |
|----------|-------------|
| `JIRA_BASE_URL` | e.g. `https://u2xai.atlassian.net` |
| `JIRA_EMAIL` | JIRA account email |
| `JIRA_API_TOKEN` | JIRA API token |

### Application Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `DEMO_MODE` | `false` | Set to `true` to run without Oracle DB (uses mock data) |
| `BUNDLE_PATH` | `/app/bundle_2026-Mar-01/MENU/analyzers/SQL` | Path to analyzer SQL files inside the container (no need to change) |
| `SECRET_KEY` | *(auto-generated)* | Flask session secret key |
| `LOG_LEVEL` | `INFO` | Logging level (`DEBUG`, `INFO`, `WARNING`, `ERROR`) |
| `PORT` | `8000` | Server port (Render sets this automatically) |

## Step 3: Deploy

1. Click **Create Web Service**
2. Render will build the Docker image and start the container
3. Watch the build logs for any errors
4. Once deployed, your app will be available at: `https://ebs-support-agent.onrender.com` (or your custom domain)

## Step 4: Verify

1. Open the Render URL in your browser
2. Check the dashboard loads correctly
3. If using live Oracle DB, test a query to verify DB connectivity
4. If `DEMO_MODE=true`, the app will show mock data

## Troubleshooting

### App fails to connect to Oracle DB
- Verify `ORACLE_HOST_IP` is the correct public IP
- Ensure Oracle DB port (1521) is open to Render's IP ranges
- Check Render logs for connection errors
- Set `DEMO_MODE=true` temporarily to verify the app itself works

### Build fails
- Check Render build logs for Python dependency errors
- Ensure `requirements.txt` is up to date

### App starts but pages don't load
- Check Render logs for Flask startup errors
- Verify `ANTHROPIC_API_KEY` is set correctly

## Blueprint Deploy (Alternative)

Instead of manual setup, you can use the `render.yaml` blueprint:
1. In Render dashboard, click **New** -> **Blueprint**
2. Connect the repo
3. Render will read `render.yaml` and pre-configure the service
4. You still need to fill in the `sync: false` env vars manually

## Architecture

```
Render Container
+----------------------------------+
|  entrypoint.sh                   |
|  1. Writes /etc/hosts entry      |
|     (ORACLE_HOST_IP -> ORACLE_HOST)|
|  2. Starts gunicorn              |
|                                  |
|  gunicorn (2 workers, 4 threads) |
|    -> app.py (Flask)             |
|       -> agents/                 |
|       -> tools/oracle_db.py      |
|       -> config/                 |
|       -> templates/ + static/    |
+----------------------------------+
         |
         | python-oracledb (thin mode)
         v
   Oracle EBS Database
   (resolved via /etc/hosts)
```

## Updating the App

Push changes to the `master` branch on GitHub. Render will auto-deploy:

```bash
git add .
git commit -m "your changes"
git push origin master
```
