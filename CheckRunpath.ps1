<#
.SYNOPSIS
检查指定路径下.so库文件的RUNPATH信息

.DESCRIPTION
该脚本会在指定项目路径下递归搜索用户输入的.so库文件（支持*通配符），
并使用llvm-readobj检查是否存在RUNPATH信息。

.PARAMETER ProjectPath
要搜索的项目根路径

.PARAMETER LibraryNames
要检查的.so库文件名列表，用逗号分隔，可使用*匹配所有.so文件

.EXAMPLE
.\CheckRunpath.ps1 -ProjectPath "/home/user/projects" -LibraryNames "libssl.so,libcrypto.so"
.\CheckRunpath.ps1 -ProjectPath "/home/user/projects" -LibraryNames "*"  # 检查所有.so文件
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$true)]
    [string]$LibraryNames
)

# 检查llvm-readobj是否可用
if (-not (Get-Command "llvm-readobj" -ErrorAction SilentlyContinue)) {
    Write-Host "错误: llvm-readobj工具未找到，请确保已安装LLVM工具链" -ForegroundColor Red
    exit 1
}

# 检查项目路径是否存在
if (-not (Test-Path $ProjectPath)) {
    Write-Host "错误: 项目路径 '$ProjectPath' 不存在" -ForegroundColor Red
    exit 1
}

# 统计结果
$results = @()

# 判断是否使用通配符扫描所有.so文件
if ($LibraryNames -eq "*") {
    Write-Host "`n正在搜索所有.so库文件..." -ForegroundColor Cyan
    $foundFiles = Get-ChildItem -Path $ProjectPath -Recurse -Filter "*.so" -ErrorAction SilentlyContinue
} else {
    # 分割库名列表
    $libs = $LibraryNames.Split(',').Trim()
    $foundFiles = @()
    
    foreach ($lib in $libs) {
        # 确保库文件名以.so结尾
        if (-not $lib.EndsWith(".so")) {
            $lib = $lib + ".so"
        }

        Write-Host "`n正在搜索库文件: $lib" -ForegroundColor Cyan
        $foundFiles += Get-ChildItem -Path $ProjectPath -Recurse -Filter $lib -ErrorAction SilentlyContinue
    }
}

# 如果没有找到任何文件
if ($foundFiles.Count -eq 0) {
    Write-Host "未找到任何.so库文件" -ForegroundColor Yellow
    exit 0
}

# 去重处理
$uniqueFiles = $foundFiles | Sort-Object FullName -Unique

# 检查每个找到的库文件
foreach ($file in $uniqueFiles) {
    Write-Host "`n检查文件: $($file.FullName)" -ForegroundColor Green

    # 使用llvm-readobj检查RUNPATH
    $readobjOutput = llvm-readobj --dynamic-table $file.FullName 2>&1
    
    # 检查RUNPATH或RPATH
    $hasRunpath = $readobjOutput -match "RUNPATH"
    $hasRpath = $readobjOutput -match "RPATH"
    
    $runpathValue = if ($hasRunpath) {
        ($readobjOutput | Select-String -Pattern "RUNPATH\s+.*?(/.*)").Matches.Groups[1].Value
    } elseif ($hasRpath) {
        ($readobjOutput | Select-String -Pattern "RPATH\s+.*?(/.*)").Matches.Groups[1].Value
    } else {
        "未设置"
    }

    $runpathStatus = if ($hasRunpath -or $hasRpath) {
        "存在"
    } else {
        "不存在"
    }

    Write-Host "RUNPATH/RPATH状态: $runpathStatus" -ForegroundColor ($runpathStatus -eq "存在" ? "Yellow" : "Green")
    if ($runpathStatus -eq "存在") {
        Write-Host "路径值: $runpathValue" -ForegroundColor Cyan
    }

    $results += [PSCustomObject]@{
        LibraryName = $file.Name
        Path = $file.FullName
        RunpathStatus = $runpathStatus
        RunpathType = if ($hasRunpath) { "RUNPATH" } elseif ($hasRpath) { "RPATH" } else { "N/A" }
        RunpathValue = $runpathValue
    }
}

# 输出汇总结果
Write-Host "`n检查结果汇总:" -ForegroundColor Magenta
$results | Format-Table -AutoSize -Property LibraryName, RunpathStatus, RunpathType, RunpathValue, Path

# 将结果导出到CSV文件
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path -Path $PWD.Path -ChildPath "runpath_report_$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "`n结果已保存到: $csvPath" -ForegroundColor Cyan

# 统计信息
$hasRunpathCount = ($results | Where-Object { $_.RunpathStatus -eq "存在" }).Count
$totalCount = $results.Count
$percentage = [math]::Round(($hasRunpathCount / $totalCount) * 100, 2)

Write-Host "`n统计信息:" -ForegroundColor Blue
Write-Host "已检查库文件总数: $totalCount"
Write-Host "设置了RUNPATH/RPATH的库文件: $hasRunpathCount ($percentage%)"