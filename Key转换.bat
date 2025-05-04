@echo off
setlocal enabledelayedexpansion

echo 请输入您的API密钥(每行一个，输入完成后按Ctrl+Z并按Enter结束):
echo.

REM 创建临时文件来存储输入
set tempfile=%temp%\apikeys.tmp
type nul > %tempfile%

REM 读取多行输入
echo 开始输入(Ctrl+Z结束):
type con > %tempfile%

echo.
echo 您的输入已接收，正在处理...

REM 初始化变量
set "output=["
set "first=yes"

REM 读取临时文件中的每一行并构建JSON数组
for /f "usebackq delims=" %%a in ("%tempfile%") do (
    if "!first!"=="yes" (
        set "output=!output!"%%a""
        set "first=no"
    ) else (
        set "output=!output!,"%%a""
    )
)

REM 完成JSON数组
set "output=!output!]"

REM 显示结果
echo 格式化输出:
echo !output!

REM 清理临时文件
del %tempfile%

pause
