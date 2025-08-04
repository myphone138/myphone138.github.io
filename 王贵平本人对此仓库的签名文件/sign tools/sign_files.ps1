


# 支持命令行参数：$args[0]=sourceDir, $args[1]=targetDir, $args[2]=gpgKey
param(
    [string]$sourceDir = "K:\完整性校验_6FEC A20A@A\files\origin",
    [string]$targetDir = "K:\完整性校验_6FEC A20A@A\files\sign",
    [string]$gpgKey = "6FECA20A"
)

# 如果通过命令行调用（无param自动绑定），则兼容 $args
if ($args.Count -ge 1) { $sourceDir = $args[0] }
if ($args.Count -ge 2) { $targetDir = $args[1] }
if ($args.Count -ge 3) { $gpgKey = $args[2] }

# 检查源目录是否存在
if (!(Test-Path $sourceDir)) {
    Write-Host "源目录不存在: $sourceDir" -ForegroundColor Red
    exit 1
}
# 检查目标目录，不存在则自动创建
if (!(Test-Path $targetDir)) {
    Write-Host "目标目录不存在，自动创建: $targetDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}


Write-Host "Starting recursive file signing..."
$fileCount = 0

Write-Host "开始递归签名..."
$fileCount = 0

# 日志文件
$errorLogFile = "K:\完整性校验_6FEC A20A@A\files\sign\sign_error_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

Get-ChildItem -Path $sourceDir -Recurse -File |
Where-Object { $_.FullName -notlike "K:\完整性校验_6FEC A20A@A\王贵平本人对此仓库的签名文件*" } |
ForEach-Object {
    $fileCount++
    $file = $_
    $relativePath = $file.FullName.Substring($sourceDir.Length + 1)
    $relativeDir = Split-Path $relativePath -Parent
    
    Write-Host "Checking file: $($file.FullName)"
    
    if ($file.Extension -ne '.sig') {
        Write-Host "Relative path: $relativePath"
        Write-Host "Relative directory: $relativeDir"
        
        # Create target directory structure
        if ($relativeDir) {
            $targetSubDir = Join-Path $targetDir $relativeDir
            if (!(Test-Path $targetSubDir)) {
                Write-Host "Creating directory: $targetSubDir"
                New-Item -ItemType Directory -Path $targetSubDir -Force | Out-Null
            }
            $sigOutputPath = Join-Path $targetSubDir "$($file.Name).sig"
        } else {
            $sigOutputPath = Join-Path $targetDir "$($file.Name).sig"
        }
        
        Write-Host "Signature output path: $sigOutputPath"
        Write-Host "Signing: $($file.Name) (path: $relativePath)"
        
        # Execute GPG signing
        # 执行 GPG 签名
        $gpgArgs = @(
            '--local-user', $gpgKey,
            '--digest-algo', 'SHA256',
            '--s2k-digest-algo', 'SHA256',
            '--personal-digest-preferences', 'SHA256',
            '--detach-sign',
            '--armor',
            '-o', $sigOutputPath,
            $file.FullName
        )
        
        $result = & gpg @gpgArgs 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "签名成功: $($file.Name)"
        } else {
            Write-Host "签名失败: $($file.Name)"
            Write-Host $result
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $logEntry = "[$timestamp] 文件: $($file.FullName) | 错误: $result"
            Add-Content -Path $errorLogFile -Value $logEntry -Encoding UTF8
        }
    }
}

Write-Host "Total files checked: $fileCount" 