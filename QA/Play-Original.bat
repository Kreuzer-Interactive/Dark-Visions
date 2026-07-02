@echo off
title Dark Visions - ORIGINAL v1.03.01
set "HERE=%~dp0"
set "CFG=%TEMP%\dv_play_original.conf"
(
echo [sdl]
echo output=openglnb
echo autolock=false
echo mouse_emulation=locked
echo mapperfile=%HERE%qa_original.map
echo [render]
echo aspect=true
echo [cpu]
echo cycles=47810
echo [autoexec]
echo mount c "%HERE%original"
echo c:
echo game
echo exit
) > "%CFG%"
"%HERE%DOSBox-X\dosbox-x.exe" -conf "%CFG%"
