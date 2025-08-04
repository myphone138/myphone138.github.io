@echo off
chcp 65001
setlocal enabledelayedexpansion

set /a total=0
set /a good=0
set /a bad=0
set "badfiles="

rem 只遍历 K:\完整性校验\files\origin 文件夹及其子文件夹的文件
for /r "K:\完整性校验_6FEC A20A@A\files\origin" %%f in (*) do (
    set "orig_path=%%~dpnxf"
    set "sig_path=!orig_path:K:\完整性校验_6FEC A20A@A\files\origin\=K:\完整性校验_6FEC A20A@A\files\sign\!.sig"
    if exist "!sig_path!" (
        set /a total+=1
        <nul set /p=正在验证: %%f  
        gpg --verify "!sig_path!" "%%f" 2>&1 | findstr /C:"Good signature" /C:"BAD signature" >nul
        if !errorlevel! == 0 (
            gpg --verify "!sig_path!" "%%f" 2>&1 | findstr /C:"Good signature" >nul
            if !errorlevel! == 0 (
                set /a good+=1
                rem 绿色输出
                call :EchoColor 0A "  签名有效"
            ) else (
                set /a bad+=1
                set "badfiles=!badfiles!%%f;"
                rem 红色输出
                call :EchoColor 0C "  签名无效"
            )
        ) else (
            set /a bad+=1
            set "badfiles=!badfiles!%%f;"
            call :EchoColor 0C "  签名无效"
        )
    )
)

echo.
echo ========== 验证统计 ==========
echo 总验证文件数: %total%
echo 签名有效数: %good%
echo 签名无效数: %bad%
if not "%badfiles%"=="" (
    echo.
    echo 无效签名文件列表:
    for %%b in (%badfiles:;= %%) do (
        echo   %%b
    )
)
echo ============================
echo 批量验证完成！
pause

goto :eof

:EchoColor
REM 用法: call :EchoColor 颜色  "内容"
REM 颜色如 0A 绿色, 0C 红色, 07 白色
setlocal
set "_color=%~1"
set "_msg=%~2"
for /f "delims=" %%c in ("%_color%") do (
    >nul 2>&1 call :_setColor %%c
    echo %_msg%
    >nul 2>&1 call :_setColor 07
)
endlocal & goto :eof

:_setColor
REM 设置控制台颜色
if "%1"=="" (color 07) else color %1
goto :eof