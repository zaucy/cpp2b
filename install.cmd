@echo off

set cpp2b_dist=%~dp0dist\debug\cpp2b

call %~dp0build.cmd

xcopy /y /q %cpp2b_dist%.exe %USERPROFILE%\.local\bin\
