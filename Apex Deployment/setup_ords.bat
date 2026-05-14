@echo off
REM ============================================================================
REM U2xAI EBS Agentic Apps — ORDS Setup Script for Windows
REM ============================================================================
REM Prerequisites:
REM   - Java 11+ installed and in PATH
REM   - ORDS extracted to C:\ords
REM   - APEX extracted to C:\apex
REM   - Oracle DB accessible at 140.245.24.128:1521/EBSDB
REM ============================================================================

echo =============================================
echo  U2xAI EBS Agentic Apps - ORDS Setup
echo =============================================
echo.

REM Check Java
java -version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: Java not found. Install Java 11+ from https://adoptium.net/
    pause
    exit /b 1
)
echo [OK] Java found.

REM Check ORDS directory
if not exist "C:\ords\bin\ords.exe" (
    if not exist "C:\ords\bin\ords" (
        echo ERROR: ORDS not found at C:\ords
        echo Download from: https://www.oracle.com/database/technologies/appdev/rest-data-services-downloads.html
        pause
        exit /b 1
    )
)
echo [OK] ORDS found.

REM Check APEX images
if not exist "C:\apex\images" (
    echo WARNING: APEX images not found at C:\apex\images
    echo Download APEX from: https://www.oracle.com/tools/downloads/apex-downloads/
    echo.
)

REM Configure ORDS
echo.
echo Configuring ORDS...
echo You will be prompted for the SYS password.
echo.

cd /d C:\ords\bin
ords install ^
  --admin-user SYS ^
  --db-hostname 140.245.24.128 ^
  --db-port 1521 ^
  --db-servicename EBSDB ^
  --feature-sdw true ^
  --log-folder C:\ords\logs ^
  --config-dir C:\ords\config

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: ORDS configuration failed.
    pause
    exit /b 1
)

REM Copy APEX static files
echo.
echo Copying APEX static files...
if exist "C:\apex\images" (
    mkdir "C:\ords\config\global\doc_root\i" 2>nul
    xcopy /E /I /Y "C:\apex\images" "C:\ords\config\global\doc_root\i" >nul
    echo [OK] APEX images copied.
) else (
    echo [SKIP] No APEX images directory found.
)

echo.
echo =============================================
echo ORDS setup complete!
echo.
echo To start ORDS, run:
echo   start_ords.bat
echo.
echo Then open: http://localhost:8080/ords/apex_admin
echo =============================================
pause
