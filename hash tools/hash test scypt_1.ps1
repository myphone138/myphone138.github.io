# =============================================================================
# 脚本信息
# =============================================================================
# 脚本名称: 文件哈希计算与校验脚本
# 设计者: 天外流星
# 脚本存储路径: E:\证据\正卷对比\一体化工具\1哈希工具
# 创建时间: $(Get-Date -Format "yyyy年M月d日 HH:mm:ss")
# 功能描述: 递归计算目录下所有文件的SHA256哈希值，生成CSV格式报告
# =============================================================================

$outputFile = "K:\完整性校验_6FEC A20A@A\hash\all_files_hash.csv"
$counter = 1

# 校验信息（可根据实际情况修改）
$checkerName = "王贵平"
$checkerGPGKeyID = "sec_ID=4BC2 688A 6D17 9053 F19B  C5B2 2FFC AC97 6FEC A20A&pub_ID=839C 460C BDE4 F58A 75BE  482C 8342 EA94 1D2E 1425"
$gpgPublicKeyPath = "J:\138\138gpg\王贵平_0x6FECA20A_public.asc"

# 设置时区为北京时间
[System.TimeZoneInfo]::ClearCachedData()
$beijingTimeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")

# 获取当前北京时间作为校验时间
$checkTime = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $beijingTimeZone).ToString("yyyy年M月d日 HH:mm:ss")

$errorLogFile = "K:\完整性校验_6FEC A20A@A\hash\hash_error_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$errorCount = 0
$successCount = 0
$timeAnomalyCount = 0

# 格式化文件大小的函数
function Format-FileSize {
    param([long]$Size)
    if ($Size -lt 1) { return "$Size bit" }
    elseif ($Size -lt 1KB) { return "$Size B" }
    elseif ($Size -lt 1MB) { return "$([math]::Round($Size/1KB, 2)) KB" }
    elseif ($Size -lt 1GB) { return "$([math]::Round($Size/1MB, 2)) MB" }
    else { return "$([math]::Round($Size/1GB, 2)) GB" }
}

# 安全转换文件时间的函数
function Convert-FileTimeToBeijing {
    param([DateTime]$fileTime)
    try {
        # 处理不同的时间类型
        if ($fileTime.Kind -eq [DateTimeKind]::Unspecified) {
            # 未指定类型的时间，假设是本地时间
            $utcTime = $fileTime.ToUniversalTime()
        } elseif ($fileTime.Kind -eq [DateTimeKind]::Local) {
            $utcTime = $fileTime.ToUniversalTime()
        } else {
            # UTC时间
            $utcTime = $fileTime
        }
        
        # 转换为北京时间
        $beijingTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcTime, $beijingTimeZone)
        return $beijingTime.ToString("yyyy年M月d日 HH:mm:ss")
    } catch {
        # 如果转换失败，直接使用原始时间
        return $fileTime.ToString("yyyy年M月d日 HH:mm:ss")
    }
}

# 记录错误的函数
function Write-ErrorLog {
    param(
        [string]$FilePath,
        [string]$ErrorMessage
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] 文件: $FilePath | 错误: $ErrorMessage"
    Add-Content -Path $errorLogFile -Value $logEntry -Encoding UTF8
    Write-Host "错误: $logEntry" -ForegroundColor Red
    $script:errorCount++
}

# 记录时间异常的函数
function Write-TimeAnomalyLog {
    param(
        [string]$FileName,
        [string]$CreationTime,
        [string]$LastWriteTime,
        [string]$TimeDiff
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] 时间异常: $FileName | 创建时间: $CreationTime | 修改时间: $LastWriteTime | 时间差: $TimeDiff"
    Add-Content -Path $errorLogFile -Value $logEntry -Encoding UTF8
    Write-Host "时间异常: $logEntry" -ForegroundColor Yellow
    $script:timeAnomalyCount++
}

# 创建CSV内容
$csvContent = @()

# 添加文件哈希数据
Write-Host "开始处理文件..." -ForegroundColor Green

Get-ChildItem -Path "K:\完整性校验_6FEC A20A@A\files" -File -Recurse | ForEach-Object {
    try {
        # 检查文件是否可访问
        if (-not (Test-Path $_.FullName -PathType Leaf)) {
            Write-ErrorLog $_.FullName "文件不存在或无法访问"
            return
        }

        # 尝试获取文件哈希
        $hash = Get-FileHash $_.FullName -Algorithm SHA256 -ErrorAction Stop
        $formattedSize = Format-FileSize $_.Length
        
        # 获取原始时间信息
        $originalCreationTime = $_.CreationTime
        $originalLastWriteTime = $_.LastWriteTime
        
        # 安全转换文件时间为北京时间
        $fileCreationTime = Convert-FileTimeToBeijing $_.CreationTime
        $fileLastWriteTime = Convert-FileTimeToBeijing $_.LastWriteTime
        
        # 验证时间逻辑性
        $timeAnomaly = $false
        $timeDiff = ""
        
        try {
            $creationDateTime = [DateTime]::ParseExact($fileCreationTime, "yyyy年M月d日 HH:mm:ss", $null)
            $lastWriteDateTime = [DateTime]::ParseExact($fileLastWriteTime, "yyyy年M月d日 HH:mm:ss", $null)
            
            if ($creationDateTime -gt $lastWriteDateTime) {
                $timeAnomaly = $true
                $timeDiff = ($creationDateTime - $lastWriteDateTime).TotalMinutes.ToString("F2") + " 分钟"
                Write-TimeAnomalyLog $_.Name $fileCreationTime $fileLastWriteTime $timeDiff
                Write-Host "文件 $($_.Name) 时间异常 - 原始创建时间: $originalCreationTime, 原始修改时间: $originalLastWriteTime" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "无法解析文件 $($_.Name) 的时间格式" -ForegroundColor Yellow
        }
        
        # 在文件名中添加时间异常标记
        $displayFileName = $_.Name
        if ($timeAnomaly) {
            $displayFileName = $_.Name + " [时间异常]"
        }
        
        $csvContent += [PSCustomObject]@{
            序号 = $counter
            算法 = $hash.Algorithm
            文件名 = $displayFileName
            哈希值 = $hash.Hash
            大小 = $formattedSize
            创建时间 = $fileCreationTime
            修改时间 = $fileLastWriteTime
            文件路径 = $_.FullName
        }
        
        $counter++
        $successCount++
        
        # 显示进度
        if ($successCount % 100 -eq 0) {
            Write-Host "已处理 $successCount 个文件..." -ForegroundColor Yellow
        }
        
    } catch [System.UnauthorizedAccessException] {
        Write-ErrorLog $_.FullName "权限不足，无法访问文件"
    } catch [System.IO.IOException] {
        Write-ErrorLog $_.FullName "文件被占用或IO错误: $($_.Exception.Message)"
    } catch [System.Security.SecurityException] {
        Write-ErrorLog $_.FullName "安全异常: $($_.Exception.Message)"
    } catch {
        Write-ErrorLog $_.FullName "未知错误: $($_.Exception.Message)"
    }
}

# 添加空行
$csvContent += [PSCustomObject]@{
    序号 = ""
    算法 = ""
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

# 添加校验信息
$csvContent += [PSCustomObject]@{
    序号 = "校验时间"
    算法 = $checkTime
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "校验人姓名"
    算法 = $checkerName
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "校验人GPG密钥ID"
    算法 = $checkerGPGKeyID
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "公钥获取地址"
    算法 = $gpgPublicKeyPath
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

# 添加处理统计信息
$csvContent += [PSCustomObject]@{
    序号 = "成功处理文件数"
    算法 = $successCount
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "处理失败文件数"
    算法 = $errorCount
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "时间异常文件数"
    算法 = $timeAnomalyCount
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

# 添加脚本信息
$csvContent += [PSCustomObject]@{
    序号 = "脚本名称"
    算法 = "文件哈希计算与校验脚本"
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "脚本设计者"
    算法 = "天外流星"
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "脚本存储路径"
    算法 = "K:\完整性校验_6FEC A20A@A\hash tools\hash test scypt_1.ps1"
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

$csvContent += [PSCustomObject]@{
    序号 = "脚本执行时间"
    算法 = $(Get-Date -Format "yyyy年M月d日 HH:mm:ss")
    文件名 = ""
    哈希值 = ""
    大小 = ""
    创建时间 = ""
    修改时间 = ""
    文件路径 = ""
}

# 导出到CSV文件
try {
    $csvContent | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $outputFile -Encoding UTF8 -ErrorAction Stop
    Write-Host "`n处理完成！" -ForegroundColor Green
    Write-Host "文件已保存为: $outputFile" -ForegroundColor Green
    Write-Host "校验时间: $checkTime" -ForegroundColor Cyan
    Write-Host "校验人: $checkerName" -ForegroundColor Cyan
    Write-Host "GPG密钥ID: $checkerGPGKeyID" -ForegroundColor Cyan
    Write-Host "公钥获取地址: $gpgPublicKeyPath" -ForegroundColor Cyan
    Write-Host "成功处理文件数: $successCount" -ForegroundColor Green
    Write-Host "处理失败文件数: $errorCount" -ForegroundColor Red
    Write-Host "时间异常文件数: $timeAnomalyCount" -ForegroundColor Yellow
    
    # 显示脚本信息
    Write-Host "`n脚本信息:" -ForegroundColor Cyan
    Write-Host "脚本名称: 文件哈希计算与校验脚本" -ForegroundColor Cyan
    Write-Host "脚本设计者: 天外流星" -ForegroundColor Cyan
    Write-Host "脚本存储路径: F:\权属固化\固化工具库\1哈希工具\No_1.ps1" -ForegroundColor Cyan
    Write-Host "脚本执行时间: $(Get-Date -Format 'yyyy年M月d日 HH:mm:ss')" -ForegroundColor Cyan
    
    if ($errorCount -gt 0 -or $timeAnomalyCount -gt 0) {
        Write-Host "详细日志已保存为: $errorLogFile" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "保存CSV文件时发生错误: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "请检查文件路径和权限" -ForegroundColor Red
} 
