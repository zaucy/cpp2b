@echo off

set cpp2b_dist=%~dp0dist\debug\cpp2b
set cpp2b_share_dir=%~dp0share

call %~dp0build.cmd

xcopy /y /q %cpp2b_dist%.exe %USERPROFILE%\.local\bin\
xcopy /y /q %cpp2b_dist%.pdb %USERPROFILE%\.local\bin\
xcopy /e /i /h /y %cpp2b_share_dir% %USERPROFILE%\.local\share

