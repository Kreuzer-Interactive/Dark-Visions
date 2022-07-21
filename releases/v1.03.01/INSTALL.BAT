echo off
echo This will install to c:\Darkv
echo press control-break to abort if
echo this is not the desired directory
pause
echo Take a look!
echo Its in your head, just waiting to get out!
c:\
cd\
md darkv
cd\darkv
a:\
copy dark.lzh c:\darkv
copy instruct.txt c:\darkv
copy lha c:\darkv
c:
echo Prepare for exploding files!
lha e dark.lzh
erase dark.lzh
echo Installation is complete
echo type darkv to run




