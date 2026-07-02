@echo off
title Dark Visions - CURRENT build (this round of changes)
set "HERE=%~dp0"
set "CFG=%TEMP%\dv_play_current.conf"
(
echo [sdl]
echo output=openglnb
echo autolock=false
echo mouse_emulation=locked
echo [render]
echo aspect=true
echo [cpu]
echo cycles=47810
echo [autoexec]
echo mount c "%HERE%current"
echo c:
echo game
echo exit
) > "%CFG%"
"%HERE%DOSBox-X\dosbox-x.exe" -conf "%CFG%"
