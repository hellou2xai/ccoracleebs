@echo off
REM ============================================================================
REM U2xAI EBS Agentic Apps — Deploy SQL Objects to Oracle DB
REM ============================================================================
REM Runs install.sql against the Oracle EBS database.
REM Requires SQL*Plus or SQLcl in PATH.
REM ============================================================================

echo =============================================
echo  U2xAI EBS Agentic Apps - Deploy to Oracle DB
echo =============================================
echo.

set DB_HOST=140.245.24.128
set DB_PORT=1521
set DB_SERVICE=EBSDB
set DB_USER=IZU

set /p DB_PASS=Enter password for %DB_USER%@%DB_SERVICE% (default: IZU1001u):

echo.
echo Connecting to %DB_USER%@//%DB_HOST%:%DB_PORT%/%DB_SERVICE%...
echo.

cd /d "%~dp0"

REM Try SQLcl first, fall back to SQL*Plus
where sql >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Using SQLcl...
    sql %DB_USER%/%DB_PASS%@//%DB_HOST%:%DB_PORT%/%DB_SERVICE% @install.sql
) else (
    where sqlplus >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo Using SQL*Plus...
        sqlplus %DB_USER%/%DB_PASS%@//%DB_HOST%:%DB_PORT%/%DB_SERVICE% @install.sql
    ) else (
        echo ERROR: Neither SQLcl nor SQL*Plus found in PATH.
        echo Install one of:
        echo   SQLcl:    https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/
        echo   SQL*Plus: Included with Oracle Instant Client
        pause
        exit /b 1
    )
)

echo.
echo =============================================
echo SQL deployment complete.
echo.
echo Next: Import 05_apex_app.sql via APEX App Builder
echo   1. Open http://localhost:8080/ords/f?p=4550
echo   2. App Builder ^> Import ^> Upload 05_apex_app.sql
echo =============================================
pause
