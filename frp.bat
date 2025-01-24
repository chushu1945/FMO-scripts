@echo off
setlocal enabledelayedexpansion

:: 设置工作目录
set "workdir=D:\AP\frp"
cd /d "%workdir%"

:: 初始化变量
set /a index=0
set files=

:: 查找所有 .toml 文件并存入数组
for %%f in (*.toml) do (
    set /a index+=1
    set "files[!index!]=%%f"
    echo !index!. %%f
)

:: 检查是否有 .toml 文件
if %index%==0 (
    echo 未找到任何 .toml 文件！
    pause
    exit /b
)

:: 提示用户选择
:select
set /p "choice=请输入要运行的文件编号 (1-%index%)："

:: 验证输入是否有效
if "%choice%"=="" goto select
if %choice% lss 1 goto select
if %choice% gtr %index% goto select

:: 获取选择的文件
set "selected_file=!files[%choice%]!"
echo 你选择了：%selected_file%

:: 执行 frpc.exe 命令
frpc.exe -c "%selected_file%"

pause
