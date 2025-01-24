@echo off
setlocal enabledelayedexpansion

:: ���ù���Ŀ¼
set "workdir=D:\AP\frp"
cd /d "%workdir%"

:: ��ʼ������
set /a index=0
set files=

:: �������� .toml �ļ�����������
for %%f in (*.toml) do (
    set /a index+=1
    set "files[!index!]=%%f"
    echo !index!. %%f
)

:: ����Ƿ��� .toml �ļ�
if %index%==0 (
    echo δ�ҵ��κ� .toml �ļ���
    pause
    exit /b
)

:: ��ʾ�û�ѡ��
:select
set /p "choice=������Ҫ���е��ļ���� (1-%index%)��"

:: ��֤�����Ƿ���Ч
if "%choice%"=="" goto select
if %choice% lss 1 goto select
if %choice% gtr %index% goto select

:: ��ȡѡ����ļ�
set "selected_file=!files[%choice%]!"
echo ��ѡ���ˣ�%selected_file%

:: ִ�� frpc.exe ����
frpc.exe -c "%selected_file%"

pause
