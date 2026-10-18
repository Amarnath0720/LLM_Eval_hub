@echo off
setlocal
set "PROJECT_DIR=%~dp0"
set "PYTHON=%~dp0.venv\Scripts\python.exe"

echo ==========================================
echo       LLM EVALUATION DASHBOARD
echo ==========================================
echo.

cd /d "%PROJECT_DIR%"
if errorlevel 1 goto PROJECT_DIR_ERROR

if not exist "%PYTHON%" goto VENV_ERROR

echo Checking required Python dependencies...
"%PYTHON%" -c "import fastapi, uvicorn, sqlalchemy, pydantic, dotenv, streamlit, requests, pandas, plotly, openai, google.genai" >nul 2>&1
if errorlevel 1 goto DEPENDENCY_ERROR

echo Checking FastAPI backend on port 8001...
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8001/health -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto BACKEND_READY

call :CHECK_PORT 8001
if not errorlevel 1 goto BACKEND_PORT_ERROR

echo Starting FastAPI backend...
start "LLM Eval Backend" /D "%PROJECT_DIR%" "%ComSpec%" /k ""%PYTHON%" -m uvicorn app.main:app --host 127.0.0.1 --port 8001"

echo Waiting up to 30 seconds for FastAPI and its database...
set /a WAITED=0
:WAIT_BACKEND
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8001/health -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto BACKEND_READY
set /a WAITED+=1
if %WAITED% GEQ 30 goto BACKEND_TIMEOUT
timeout /t 1 /nobreak >nul
goto WAIT_BACKEND

:BACKEND_READY
echo FastAPI is healthy.
echo.
echo Checking Streamlit dashboard on port 8501...
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8501/_stcore/health -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto FRONTEND_READY

call :CHECK_PORT 8501
if not errorlevel 1 goto FRONTEND_PORT_ERROR

echo Starting Streamlit dashboard...
start "LLM Eval Dashboard" /D "%PROJECT_DIR%" "%ComSpec%" /k ""%PYTHON%" -m streamlit run streamlit_app.py --server.address 127.0.0.1 --server.port 8501"

echo Waiting up to 30 seconds for Streamlit...
set /a WAITED=0
:WAIT_FRONTEND
powershell -NoProfile -Command "try { $r=Invoke-WebRequest -UseBasicParsing http://127.0.0.1:8501/_stcore/health -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
if not errorlevel 1 goto FRONTEND_READY
set /a WAITED+=1
if %WAITED% GEQ 30 goto FRONTEND_TIMEOUT
timeout /t 1 /nobreak >nul
goto WAIT_FRONTEND

:FRONTEND_READY
echo Streamlit is healthy.
echo Opening the dashboard at http://localhost:8501
start "" "http://localhost:8501"
echo.
echo The backend is at http://127.0.0.1:8001
echo API documentation: http://127.0.0.1:8001/docs
echo Close this window to finish.
pause
exit /b 0

:PROJECT_DIR_ERROR
echo ERROR: Could not switch to the project directory:
echo "%PROJECT_DIR%"
goto FAIL

:VENV_ERROR
echo ERROR: The project virtual environment was not found:
echo "%PYTHON%"
echo.
echo Open PowerShell in this folder and run:
echo   py -m venv .venv
echo   .\.venv\Scripts\python.exe -m pip install -r requirements.txt
goto FAIL

:DEPENDENCY_ERROR
echo ERROR: One or more required packages are missing from .venv.
echo Install them from this project folder with:
echo   .\.venv\Scripts\python.exe -m pip install -r requirements.txt
goto FAIL

:BACKEND_PORT_ERROR
echo ERROR: Port 8001 is occupied, but the service is not a healthy LLM-EvalHub backend.
echo Close the conflicting application and run this launcher again.
goto FAIL

:BACKEND_TIMEOUT
echo ERROR: FastAPI did not become healthy within 30 seconds.
echo Check the "LLM Eval Backend" window for startup or database errors.
goto FAIL

:FRONTEND_PORT_ERROR
echo ERROR: Port 8501 is occupied, but the service is not a healthy Streamlit dashboard.
echo Close the conflicting application and run this launcher again.
goto FAIL

:FRONTEND_TIMEOUT
echo ERROR: Streamlit did not become healthy within 30 seconds.
echo Check the "LLM Eval Dashboard" window for startup errors.
goto FAIL

:CHECK_PORT
powershell -NoProfile -Command "$tcp=New-Object Net.Sockets.TcpClient; try { $tcp.Connect('127.0.0.1',%1); exit 0 } catch { exit 1 } finally { $tcp.Dispose() }" >nul 2>&1
exit /b %errorlevel%

:FAIL
echo.
echo Startup stopped. No database files were deleted or reset.
pause
exit /b 1
