@echo off

set root_dir=%~dp0
set cpp2b_dist=%~dp0dist\debug\cpp2b

if not exist "%cpp2b_dist%.exe" (
	call %~dp0build.cmd
)

"%cpp2b_dist%.exe" %*
