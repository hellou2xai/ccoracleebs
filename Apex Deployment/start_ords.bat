@echo off
REM ============================================================================
REM U2xAI EBS Agentic Apps — Start ORDS
REM ============================================================================

echo Starting Oracle REST Data Services on port 8080...
echo Press Ctrl+C to stop.
echo.
echo App URL:  http://localhost:8080/ords/f?p=U2XEBS
echo Admin:    http://localhost:8080/ords/apex_admin
echo REST API: http://localhost:8080/ords/u2xebs/api/system/health
echo.

cd /d C:\ords\bin
ords serve --port 8080
