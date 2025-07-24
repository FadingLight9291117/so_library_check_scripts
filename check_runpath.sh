#!/bin/bash

# check_runpath.sh - 检查指定路径下.so库文件的RUNPATH信息
#
# 该脚本会在指定项目路径下递归搜索用户输入的.so库文件（支持*通配符），
# 并使用llvm-readobj检查是否存在RUNPATH信息。
#
# 用法:
#   ./check_runpath.sh <项目路径> <库文件名列表>
#
# 示例:
#   ./check_runpath.sh /home/user/projects "libssl.so,libcrypto.so"
#   ./check_runpath.sh /home/user/projects "*"  # 检查所有.so文件

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 检查参数
if [ $# -ne 2 ]; then
    echo -e "${RED}错误: 参数不正确${NC}"
    echo "用法: $0 <项目路径> <库文件名列表>"
    echo "示例: $0 /home/user/projects \"libssl.so,libcrypto.so\""
    echo "      $0 /home/user/projects \"*\"  # 检查所有.so文件"
    exit 1
fi

PROJECT_PATH="$1"
LIBRARY_NAMES="$2"

# 检查llvm-readobj是否可用
if ! command -v llvm-readobj &> /dev/null; then
    echo -e "${RED}错误: llvm-readobj工具未找到，请确保已安装LLVM工具链${NC}"
    exit 1
fi

# 检查项目路径是否存在
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}错误: 项目路径 '$PROJECT_PATH' 不存在${NC}"
    exit 1
fi

# 创建临时文件存储结果
TEMP_RESULTS=$(mktemp)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
CSV_FILE="runpath_report_$TIMESTAMP.csv"

# 写CSV头
echo "LibraryName,Path,RunpathStatus,RunpathType,RunpathValue" > "$CSV_FILE"

# 统计变量
TOTAL_COUNT=0
HAS_RUNPATH_COUNT=0

# 查找.so文件
declare -a FOUND_FILES

if [ "$LIBRARY_NAMES" = "*" ]; then
    echo -e "\n${CYAN}正在搜索所有.so库文件...${NC}"
    while IFS= read -r -d '' file; do
        FOUND_FILES+=("$file")
    done < <(find "$PROJECT_PATH" -type f -name "*.so" -print0 2>/dev/null)
else
    # 分割库名列表
    IFS=',' read -ra LIBS <<< "$LIBRARY_NAMES"
    
    for lib in "${LIBS[@]}"; do
        # 去除前后空格
        lib=$(echo "$lib" | xargs)
        
        # 确保库文件名以.so结尾
        if [[ ! "$lib" == *.so ]]; then
            lib="${lib}.so"
        fi
        
        echo -e "\n${CYAN}正在搜索库文件: $lib${NC}"
        while IFS= read -r -d '' file; do
            FOUND_FILES+=("$file")
        done < <(find "$PROJECT_PATH" -type f -name "$lib" -print0 2>/dev/null)
    done
fi

# 如果没有找到任何文件
if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到任何.so库文件${NC}"
    exit 0
fi

# 去重处理
readarray -t UNIQUE_FILES < <(printf '%s\n' "${FOUND_FILES[@]}" | sort -u)

# 检查每个找到的库文件
for file in "${UNIQUE_FILES[@]}"; do
    echo -e "\n${GREEN}检查文件: $file${NC}"
    
    # 使用llvm-readobj检查RUNPATH
    READOBJ_OUTPUT=$(llvm-readobj --dynamic-table "$file" 2>&1)
    
    # 检查RUNPATH或RPATH
    HAS_RUNPATH=false
    HAS_RPATH=false
    RUNPATH_VALUE="未设置"
    RUNPATH_TYPE="N/A"
    
    if echo "$READOBJ_OUTPUT" | grep -q "RUNPATH"; then
        HAS_RUNPATH=true
        RUNPATH_TYPE="RUNPATH"
        # 提取RUNPATH路径值
        RUNPATH_VALUE=$(echo "$READOBJ_OUTPUT" | grep "RUNPATH" | sed -n 's/.*RUNPATH[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
        if [ -z "$RUNPATH_VALUE" ]; then
            RUNPATH_VALUE="已设置但无法解析路径"
        fi
    elif echo "$READOBJ_OUTPUT" | grep -q "RPATH"; then
        HAS_RPATH=true
        RUNPATH_TYPE="RPATH"
        # 提取RPATH路径值
        RUNPATH_VALUE=$(echo "$READOBJ_OUTPUT" | grep "RPATH" | sed -n 's/.*RPATH[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
        if [ -z "$RUNPATH_VALUE" ]; then
            RUNPATH_VALUE="已设置但无法解析路径"
        fi
    fi
    
    if [ "$HAS_RUNPATH" = true ] || [ "$HAS_RPATH" = true ]; then
        RUNPATH_STATUS="存在"
        echo -e "RUNPATH/RPATH状态: ${YELLOW}$RUNPATH_STATUS${NC}"
        echo -e "路径值: ${CYAN}$RUNPATH_VALUE${NC}"
        ((HAS_RUNPATH_COUNT++))
    else
        RUNPATH_STATUS="不存在"
        echo -e "RUNPATH/RPATH状态: ${GREEN}$RUNPATH_STATUS${NC}"
    fi
    
    # 保存结果到临时文件和CSV
    LIBRARY_NAME=$(basename "$file")
    echo "$LIBRARY_NAME|$file|$RUNPATH_STATUS|$RUNPATH_TYPE|$RUNPATH_VALUE" >> "$TEMP_RESULTS"
    
    # 转义CSV中的逗号和引号
    CSV_RUNPATH_VALUE=$(echo "$RUNPATH_VALUE" | sed 's/"/""/g')
    if [[ "$CSV_RUNPATH_VALUE" == *,* ]] || [[ "$CSV_RUNPATH_VALUE" == *\"* ]]; then
        CSV_RUNPATH_VALUE="\"$CSV_RUNPATH_VALUE\""
    fi
    
    echo "$LIBRARY_NAME,\"$file\",$RUNPATH_STATUS,$RUNPATH_TYPE,$CSV_RUNPATH_VALUE" >> "$CSV_FILE"
    
    ((TOTAL_COUNT++))
done

# 输出汇总结果
echo -e "\n${MAGENTA}检查结果汇总:${NC}"
printf "%-30s %-15s %-12s %-40s %s\n" "LibraryName" "RunpathStatus" "RunpathType" "RunpathValue" "Path"
printf "%-30s %-15s %-12s %-40s %s\n" "----------" "-------------" "------------" "-------------" "----"

while IFS='|' read -r lib_name path status type value; do
    # 截断过长的路径和值以便显示
    short_path=$(echo "$path" | sed 's/.*\///') # 只显示文件名
    short_value="$value"
    if [ ${#value} -gt 40 ]; then
        short_value="${value:0:37}..."
    fi
    
    printf "%-30s %-15s %-12s %-40s %s\n" "$lib_name" "$status" "$type" "$short_value" "$short_path"
done < "$TEMP_RESULTS"

# 输出保存信息
echo -e "\n${CYAN}结果已保存到: $CSV_FILE${NC}"

# 统计信息
if [ $TOTAL_COUNT -gt 0 ]; then
    PERCENTAGE=$(echo "scale=2; ($HAS_RUNPATH_COUNT / $TOTAL_COUNT) * 100" | bc -l 2>/dev/null || echo "0")
else
    PERCENTAGE="0"
fi

echo -e "\n${BLUE}统计信息:${NC}"
echo "已检查库文件总数: $TOTAL_COUNT"
echo "设置了RUNPATH/RPATH的库文件: $HAS_RUNPATH_COUNT ($PERCENTAGE%)"

# 清理临时文件
rm -f "$TEMP_RESULTS"
