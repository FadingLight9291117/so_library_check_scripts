# .so库文件安全检查工具

这是一套用于检查Linux共享库(.so文件)安全配置的脚本工具集，同时提供PowerShell和Bash两种版本。包含两个主要功能：RUNPATH检查和栈保护检查。

## 功能概述

### RUNPATH检查工具
- **CheckRunpath.ps1** - PowerShell版本
- **check_runpath.sh** - Bash版本

检查.so库文件的RUNPATH/RPATH配置，帮助识别潜在的安全风险。

### 栈保护检查工具
- **CheckStackProtection.ps1** - PowerShell版本
- **check_stack_protection.sh** - Bash版本

检查.so库文件是否启用了栈保护机制，评估缓冲区溢出防护状态。

## 系统要求

### PowerShell版本依赖工具
- **PowerShell 5.0+** 或 **PowerShell Core 6.0+**
- **llvm-readobj** (用于RUNPATH检查)
- **readelf** (用于栈保护检查，通常包含在binutils或gcc工具链中)

### Bash版本依赖工具
- **Bash 4.0+**
- **llvm-readobj** (用于RUNPATH检查)
- **readelf** (用于栈保护检查，通常包含在binutils或gcc工具链中)
- **bc** (用于数学计算，大多数Linux发行版默认包含)

### 支持平台
- **Windows**: 通过WSL或原生Linux工具运行Bash版本，或使用PowerShell版本
- **Linux**: 原生支持两种版本
- **macOS**: 原生支持两种版本

## 安装说明

### PowerShell版本
1. 确保已安装PowerShell
2. 安装所需的Linux工具

### Bash版本
1. 确保系统支持Bash 4.0+
2. 安装所需的工具

### 依赖工具安装

**Ubuntu/Debian:**
```bash
sudo apt-get install llvm binutils bc
```

**CentOS/RHEL:**
```bash
sudo yum install llvm binutils bc
# 或者 (CentOS 8+)
sudo dnf install llvm binutils bc
```

**macOS:**
```bash
brew install llvm binutils
# bc通常已预装
```

## 使用方法

### RUNPATH检查

#### PowerShell版本 (CheckRunpath.ps1)

检查指定路径下.so库文件的RUNPATH信息。

##### 语法
```powershell
.\CheckRunpath.ps1 -ProjectPath <路径> -LibraryNames <库文件名>
```

##### 参数说明
- **ProjectPath**: 要搜索的项目根路径（必需）
- **LibraryNames**: 要检查的.so库文件名，用逗号分隔（必需）
  - 支持具体文件名，如: `libssl.so,libcrypto.so`
  - 支持通配符 `*` 检查所有.so文件

##### 使用示例
```powershell
# 检查特定库文件
.\CheckRunpath.ps1 -ProjectPath "/home/user/projects" -LibraryNames "libssl.so,libcrypto.so"

# 检查所有.so文件
.\CheckRunpath.ps1 -ProjectPath "/home/user/projects" -LibraryNames "*"

# 检查当前目录
.\CheckRunpath.ps1 -ProjectPath "." -LibraryNames "*"
```

#### Bash版本 (check_runpath.sh)

##### 语法
```bash
./check_runpath.sh <项目路径> <库文件名列表>
```

##### 参数说明
- **项目路径**: 要搜索的项目根路径（必需）
- **库文件名列表**: 要检查的.so库文件名，用逗号分隔（必需）
  - 支持具体文件名，如: `libssl.so,libcrypto.so`
  - 支持通配符 `*` 检查所有.so文件

##### 使用示例
```bash
# 检查特定库文件
./check_runpath.sh "/home/user/projects" "libssl.so,libcrypto.so"

# 检查所有.so文件
./check_runpath.sh "/home/user/projects" "*"

# 检查当前目录
./check_runpath.sh "." "*"

# 首次使用需要添加执行权限
chmod +x check_runpath.sh
```

#### 输出说明
两个版本的脚本都会输出：
- 每个库文件的RUNPATH/RPATH状态
- 详细的路径值（如果存在）
- 汇总表格
- CSV报告文件（格式：`runpath_report_YYYYMMDD_HHMMSS.csv`）
- 统计信息

### 栈保护检查

#### PowerShell版本 (CheckStackProtection.ps1)

检查指定路径下.so库文件的栈保护状态。

##### 语法
```powershell
.\CheckStackProtection.ps1 -ProjectPath <路径> -LibraryNames <库文件名>
```

##### 参数说明
- **ProjectPath**: 要搜索的项目根路径（必需）
- **LibraryNames**: 要检查的.so库文件名，用逗号分隔（必需）
  - 支持具体文件名，如: `libssl.so,libcrypto.so`
  - 支持通配符 `*` 检查所有.so文件

##### 使用示例
```powershell
# 检查特定库文件
.\CheckStackProtection.ps1 -ProjectPath "/home/user/projects" -LibraryNames "libssl.so,libcrypto.so"

# 检查所有.so文件
.\CheckStackProtection.ps1 -ProjectPath "/home/user/projects" -LibraryNames "*"

# 检查当前目录
.\CheckStackProtection.ps1 -ProjectPath "." -LibraryNames "*"
```

#### Bash版本 (check_stack_protection.sh)

##### 语法
```bash
./check_stack_protection.sh <项目路径> <库文件名列表>
```

##### 参数说明
- **项目路径**: 要搜索的项目根路径（必需）
- **库文件名列表**: 要检查的.so库文件名，用逗号分隔（必需）
  - 支持具体文件名，如: `libssl.so,libcrypto.so`
  - 支持通配符 `*` 检查所有.so文件

##### 使用示例
```bash
# 检查特定库文件
./check_stack_protection.sh "/home/user/projects" "libssl.so,libcrypto.so"

# 检查所有.so文件
./check_stack_protection.sh "/home/user/projects" "*"

# 检查当前目录
./check_stack_protection.sh "." "*"

# 首次使用需要添加执行权限
chmod +x check_stack_protection.sh
```

#### 输出说明
两个版本的脚本都会输出：
- 每个库文件的栈保护状态
- 编译时使用的保护级别
- 汇总表格
- CSV报告文件（格式：`stack_protection_report_YYYYMMDD_HHMMSS.csv`）
- 统计信息

## 安全检查说明

### RUNPATH检查的重要性
- **RUNPATH/RPATH** 指定了动态链接器搜索共享库的路径
- 不当的RUNPATH设置可能导致：
  - 库劫持攻击
  - 恶意库注入
  - 权限提升漏洞

### 栈保护检查的重要性
- **栈保护** 是防御缓冲区溢出攻击的重要机制
- 检查项目包括：
  - `__stack_chk_fail` 符号存在性
  - `__stack_chk_guard` 符号存在性
  - 编译器保护标志 (`-fstack-protector-*`)

## 输出文件说明

### CSV报告文件

#### RUNPATH报告字段
- **LibraryName**: 库文件名
- **Path**: 完整路径
- **RunpathStatus**: RUNPATH状态（存在/不存在）
- **RunpathType**: 类型（RUNPATH/RPATH/N/A）
- **RunpathValue**: 路径值

#### 栈保护报告字段
- **LibraryName**: 库文件名
- **Path**: 完整路径
- **StackProtection**: 栈保护状态（已启用/未启用）
- **ProtectionLevel**: 保护级别（none/basic/strong/all）
- **StackChkFail**: `__stack_chk_fail`符号状态
- **StackChkGuard**: `__stack_chk_guard`符号状态

## 故障排除

### 常见错误及解决方案

1. **"llvm-readobj工具未找到"**
   - 确保已安装LLVM工具链
   - 检查PATH环境变量是否包含llvm-readobj路径

2. **"readelf工具未找到"**
   - 确保已安装binutils或gcc工具链
   - 检查PATH环境变量

3. **"项目路径不存在"**
   - 验证提供的路径是否正确
   - 确保有足够的权限访问该路径

4. **"未找到任何.so库文件"**
   - 检查路径下是否确实存在.so文件
   - 验证文件名是否正确

5. **Bash脚本权限问题**
   ```bash
   chmod +x check_runpath.sh
   chmod +x check_stack_protection.sh
   ```

6. **"bc命令未找到" (仅Bash版本)**
   - Ubuntu/Debian: `sudo apt-get install bc`
   - CentOS/RHEL: `sudo yum install bc`

7. **PowerShell执行策略问题 (Windows)**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## 脚本对比

### 功能对比

| 特性 | PowerShell版本 | Bash版本 |
|------|---------------|----------|
| 支持平台 | Windows, Linux, macOS | Linux, macOS, Windows(WSL) |
| 参数格式 | 命名参数 (`-ProjectPath`) | 位置参数 |
| 错误处理 | PowerShell异常处理 | Bash错误检查 |
| 输出格式 | PowerShell格式化表格 | 自定义格式化 |
| 颜色输出 | PowerShell颜色 | ANSI转义序列 |
| 依赖 | PowerShell运行时 | Bash + bc |

### 选择建议

- **Windows环境**: 推荐使用PowerShell版本
- **Linux/Unix环境**: 两个版本都可以，Bash版本更原生
- **跨平台自动化**: PowerShell Core提供更好的跨平台一致性
- **传统Unix环境**: Bash版本更适合传统的Shell脚本工作流

## 示例输出

### RUNPATH检查示例
```
检查文件: /usr/lib/x86_64-linux-gnu/libssl.so.3
RUNPATH/RPATH状态: 不存在

检查结果汇总:
LibraryName  RunpathStatus RunpathType RunpathValue Path
-----------  ------------- ----------- ------------ ----
libssl.so.3  不存在        N/A         未设置       /usr/lib/x86_64-linux-gnu/libssl.so.3

统计信息:
已检查库文件总数: 1
设置了RUNPATH/RPATH的库文件: 0 (0%)
```

### 栈保护检查示例
```
检查文件: /usr/lib/x86_64-linux-gnu/libssl.so.3
栈保护状态: 已启用
编译选项: strong

检查结果汇总:
LibraryName  StackProtection ProtectionLevel Path
-----------  --------------- --------------- ----
libssl.so.3  已启用          strong          /usr/lib/x86_64-linux-gnu/libssl.so.3

统计信息:
已检查库文件总数: 1
启用栈保护的库文件: 1 (100%)
```

## 许可证

本项目采用MIT许可证。

## 贡献

欢迎提交问题报告和改进建议。

## 更新日志

- **v1.0.0**: 初始版本，包含PowerShell版本的RUNPATH和栈保护检查功能
- **v1.1.0**: 新增Bash版本脚本，提供跨平台支持和更好的Linux原生体验

## 文件清单

- `CheckRunpath.ps1` - PowerShell版RUNPATH检查工具
- `CheckStackProtection.ps1` - PowerShell版栈保护检查工具
- `check_runpath.sh` - Bash版RUNPATH检查工具
- `check_stack_protection.sh` - Bash版栈保护检查工具
- `readme.md` - 项目文档