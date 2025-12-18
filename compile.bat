@echo off
call "%ProgramFiles(x86)%\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
cl /c /GS- /O1 /Os ps-launcher.c
link /NODEFAULTLIB /ENTRY:WinMain /SUBSYSTEM:WINDOWS kernel32.lib user32.lib shell32.lib /OUT:ps-launcher.exe ps-launcher.obj
del *.obj