@echo off
REM ====================================================================
REM  SKS Family - Lanceur du serveur web local
REM  Double-cliquez sur ce fichier pour lancer l'app dans le navigateur
REM ====================================================================

title SKS Family - Serveur Web Local
cd /d "C:\Users\b2osi\ZCodeProject\Sks-familly\build\web"

echo.
echo  ============================================================
echo   SKS Family - Demarrage du serveur web...
echo  ============================================================
echo.
echo   L'app va s'ouvrir dans votre navigateur.
echo   Laissez cette fenetre ouverte pendant que vous testez.
echo   Fermez cette fenetre pour arreter le serveur.
echo.

REM Lance le serveur en arriere-plan puis ouvre le navigateur
start "" "http://127.0.0.1:8080"
npx --yes http-server -p 8080 -a 127.0.0.1 --cors -c-1

pause
