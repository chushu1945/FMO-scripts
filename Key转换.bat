@echo off
setlocal enabledelayedexpansion

echo ����������API��Կ(ÿ��һ����������ɺ�Ctrl+Z����Enter����):
echo.

REM ������ʱ�ļ����洢����
set tempfile=%temp%\apikeys.tmp
type nul > %tempfile%

REM ��ȡ��������
echo ��ʼ����(Ctrl+Z����):
type con > %tempfile%

echo.
echo ���������ѽ��գ����ڴ���...

REM ��ʼ������
set "output=["
set "first=yes"

REM ��ȡ��ʱ�ļ��е�ÿһ�в�����JSON����
for /f "usebackq delims=" %%a in ("%tempfile%") do (
    if "!first!"=="yes" (
        set "output=!output!"%%a""
        set "first=no"
    ) else (
        set "output=!output!,"%%a""
    )
)

REM ���JSON����
set "output=!output!]"

REM ��ʾ���
echo ��ʽ�����:
echo !output!

REM ������ʱ�ļ�
del %tempfile%

pause
