<#
.SYNOPSIS
检查指定路径下.so库文件的栈保护状态（支持通配符）

.DESCRIPTION
该脚本会在指定项目路径下递归搜索用户输入的.so库文件（支持*通配符），
并使用readelf检查是否启用了栈保护。

.PARAMETER ProjectPath
要搜索的项目根路径

.PARAMETER LibraryNames
要检查的.so库文件名列表，用逗号分隔，可使用*匹配所有.so文件

.EXAMPLE
.\CheckStackProtection.ps1 -ProjectPath "/home/user/projects" -LibraryNames "libssl.so,libcrypto.so"
.\CheckStackProtection.ps1 -ProjectPath "/home/user/projects" -LibraryNames "*"  # 检查所有.so文件
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,
    
    [Parameter(Mandatory=$true)]
    [string]$LibraryNames
)

# 检查readelf是否可用
if (-not (Get-Command "readelf" -ErrorAction SilentlyContinue)) {
    Write-Host "错误: readelf工具未找到，请确保已安装binutils或gcc工具链" -ForegroundColor Red
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

    # 使用readelf检查栈保护符号
    $symbols = readelf -s $file.FullName 2>&1
    $hasStackChkFail = $symbols -match "__stack_chk_fail"
    $hasStackChkGuard = $symbols -match "__stack_chk_guard"

    $protectionStatus = if ($hasStackChkFail -or $hasStackChkGuard) {
        "已启用"
    } else {
        "未启用"
    }

    # 检查编译选项中的栈保护标志
    $compileOptions = readelf -p .comment $file.FullName 2>&1
    $stackProtectorFlag = if ($compileOptions -match "-fstack-protector") {
        if ($compileOptions -match "-fstack-protector-strong") {
            "strong"
        } elseif ($compileOptions -match "-fstack-protector-all") {
            "all"
        } else {
            "basic"
        }
    } else {
        "none"
    }

    Write-Host "栈保护状态: $protectionStatus" -ForegroundColor ($protectionStatus -eq "已启用" ? "Green" : "Red")
    Write-Host "编译选项: $stackProtectorFlag" -ForegroundColor Cyan

    $results += [PSCustomObject]@{
        LibraryName = $file.Name
        Path = $file.FullName
        StackProtection = $protectionStatus
        ProtectionLevel = $stackProtectorFlag
        StackChkFail = if ($hasStackChkFail) { "存在" } else { "缺失" }
        StackChkGuard = if ($hasStackChkGuard) { "存在" } else { "缺失" }
    }
}

# 输出汇总结果
Write-Host "`n检查结果汇总:" -ForegroundColor Magenta
$results | Format-Table -AutoSize -Property LibraryName, StackProtection, ProtectionLevel, Path

# 将结果导出到CSV文件
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath = Join-Path -Path $PWD.Path -ChildPath "stack_protection_report_$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "`n结果已保存到: $csvPath" -ForegroundColor Cyan

# 统计信息
$enabledCount = ($results | Where-Object { $_.StackProtection -eq "已启用" }).Count
$totalCount = $results.Count
$percentage = [math]::Round(($enabledCount / $totalCount) * 100, 2)

Write-Host "`n统计信息:" -ForegroundColor Blue
Write-Host "已检查库文件总数: $totalCount"
Write-Host "启用栈保护的库文件: $enabledCount ($percentage%)"