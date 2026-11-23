@ECHO OFF

pushd %~dp0

if "%SPHINXBUILD%" == "" (
	set SPHINXBUILD=sphinx-build
)
set SOURCEDIR=.
set BUILDDIR=_build

%SPHINXBUILD% >NUL 2>NUL
if errorlevel 9009 (
	echo.
	echo.The 'sphinx-build' command was not found. Make sure you have Sphinx
	echo.installed, then set the SPHINXBUILD environment variable to point
	echo.to the full path of the 'sphinx-build' executable.
	echo.
	echo.Install dependencies with: pip install -r requirements.txt
	exit /b 1
)

if "%1" == "" goto help
if "%1" == "html" goto html
if "%1" == "html-strict" goto html_strict
if "%1" == "clean" goto clean

%SPHINXBUILD% -M %1 %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
goto end

:help
%SPHINXBUILD% -M help %SOURCEDIR% %BUILDDIR% %SPHINXOPTS% %O%
goto end

:html
%SPHINXBUILD% -b html %SOURCEDIR% %BUILDDIR%\html %SPHINXOPTS% %O%
goto end

:html_strict
%SPHINXBUILD% -b html -W --keep-going %SOURCEDIR% %BUILDDIR%\html %SPHINXOPTS% %O%
goto end

:clean
if exist %BUILDDIR% rmdir /s /q %BUILDDIR%
goto end

:end
popd
