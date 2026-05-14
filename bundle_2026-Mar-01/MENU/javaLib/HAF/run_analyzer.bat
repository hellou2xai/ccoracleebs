@REM ----------------------------------------------------------------------------
@REM  Copyright 2001-2006 The Apache Software Foundation.
@REM
@REM  Licensed under the Apache License, Version 2.0 (the "License");
@REM  you may not use this file except in compliance with the License.
@REM  You may obtain a copy of the License at
@REM
@REM       http://www.apache.org/licenses/LICENSE-2.0
@REM
@REM  Unless required by applicable law or agreed to in writing, software
@REM  distributed under the License is distributed on an "AS IS" BASIS,
@REM  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@REM  See the License for the specific language governing permissions and
@REM  limitations under the License.
@REM ----------------------------------------------------------------------------
@REM
@REM   Copyright (c) 2001-2006 The Apache Software Foundation.  All rights
@REM   reserved.

@echo off

set ERROR_CODE=0

:init
@REM Decide how to startup depending on the version of windows

@REM -- Win98ME
if NOT "%OS%"=="Windows_NT" goto Win9xArg

@REM set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" @setlocal

@REM -- 4NT shell
if "%eval[2+2]" == "4" goto 4NTArgs

@REM -- Regular WinNT shell
set CMD_LINE_ARGS=%*
goto WinNTGetScriptDir

@REM The 4NT Shell from jp software
:4NTArgs
set CMD_LINE_ARGS=%$
goto WinNTGetScriptDir

:Win9xArg
@REM Slurp the command line arguments.  This loop allows for an unlimited number
@REM of arguments (up to the command line limit, anyway).
set CMD_LINE_ARGS=
:Win9xApp
if %1a==a goto Win9xGetScriptDir
set CMD_LINE_ARGS=%CMD_LINE_ARGS% %1
shift
goto Win9xApp

:Win9xGetScriptDir
set SAVEDIR=%CD%
%0\
cd %0\..
set BASEDIR=%CD%
cd %SAVEDIR%
set SAVE_DIR=
goto repoSetup

:WinNTGetScriptDir
set BASEDIR=%~dp0

:repoSetup
set REPO=


if "%JAVACMD%"=="" set JAVACMD=java

if "%REPO%"=="" set REPO=%BASEDIR%lib

if EXIST "%ORACLE_HOME%"\jdbc\lib\ojdbc6.jar set JDBC_LIB=%ORACLE_HOME%\jdbc\lib\ojdbc6.jar
if EXIST "%ORACLE_HOME%"\jdbc\lib\ojdbc7.jar set JDBC_LIB=%ORACLE_HOME%\jdbc\lib\ojdbc7.jar
if EXIST "%ORACLE_HOME%"\jdbc\lib\ojdbc8.jar set JDBC_LIB=%ORACLE_HOME%\jdbc\lib\ojdbc8.jar

if "%JDBC_LIB%"=="" set JDBC_LIB=%REPO%\ojdbc7-12.1.0.1.jar

set FSGBU_LIBS=%REPO%\AZDBConnection.jar;%REPO%\ucp.jar

set OLD_CLASSPATH=%CLASSPATH%
set CLASSPATH="%REPO%"\commons-codec-1.12.jar;"%REPO%"\javax.json-api-1.0.jar;"%REPO%"\javax.json-1.0.jar;"%REPO%"\jaxb-api-2.3.1.jar;"%REPO%"\javax.activation-api-1.2.0.jar;"%REPO%"\jaxb-runtime-2.3.1.jar;"%REPO%"\txw2-2.3.1.jar;"%REPO%"\istack-commons-runtime-3.0.7.jar;"%REPO%"\stax-ex-1.8.jar;"%REPO%"\FastInfoset-1.2.15.jar;"%JDBC_LIB%";"%REPO%"\jcc-11.5.5.0.jar;"%REPO%"\mssql-jdbc-9.2.0.jre8.jar;"%FSGBU_LIBS%";"%REPO%"\SW_EBSHAF-6.26.1.jar

set ENDORSED_DIR=
if NOT "%ENDORSED_DIR%" == "" set CLASSPATH="%BASEDIR%"\%ENDORSED_DIR%\*;%CLASSPATH%

if NOT "%CLASSPATH_PREFIX%" == "" set CLASSPATH=%CLASSPATH_PREFIX%;%CLASSPATH%

@REM Reaching here means variables are defined and arguments have been captured
:endInit

@REM Adding double quotes before calling the object EBSHAF-588
set %BASEDIR%="%BASEDIR%"

%JAVACMD% %JAVA_OPTS%  -classpath %CLASSPATH% -Dapp.name="SW_EBSHAF" -Dapp.repo="%REPO%" -Dbasedir=%BASEDIR% -Dapp.home=%BASEDIR% -Dold_classpath=%OLD_CLASSPATH% %CMD_LINE_ARGS% oracle.support.proactive.hybridanalyzer.CommandLine 
if %ERRORLEVEL% NEQ 0 goto error
goto end

:error
if "%OS%"=="Windows_NT" @endlocal
set ERROR_CODE=%ERRORLEVEL%

:end
@REM set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" goto endNT

@REM For old DOS remove the set variables from ENV - we assume they were not set
@REM before we started - at least we don't leave any baggage around
set CMD_LINE_ARGS=
goto postExec

:endNT
@REM If error code is set to 1 then the endlocal was done already in :error.
if %ERROR_CODE% EQU 0 @endlocal


:postExec

if "%FORCE_EXIT_ON_ERROR%" == "on" (
  if %ERROR_CODE% NEQ 0 exit %ERROR_CODE%
)

exit /B %ERROR_CODE%
