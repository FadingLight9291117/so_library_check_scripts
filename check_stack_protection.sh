#!/bin/bash

#
# Synopsis: 检查指定路径下.so库文件的栈保护状态（支持通配符）
#
# Description: 该脚本会在指定项目路径下递归搜索用户输入的.so库文件（支持*通配符），
#              并使用readelf检查是否启用了栈保护。
#
# Parameters:
#   $1 - ProjectPath: 要搜索的项目根路径
#   $2 - LibraryNames: 要检查的.so库文件名列表，用逗号分隔，可使用*匹配所有.so文件
#
# Examples:
#   ./check_stack_protection.sh "/home/user/projects" "libssl.so,libcrypto.so"
#   ./check_stack_protection.sh "/home/user/projects" "*"  # 检查所有.so文件
#

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
    echo -e "${RED}错误: 需要提供两个参数${NC}"
    echo "用法: $0 <项目路径> <库文件名列表>"
    echo "示例: $0 \"/home/user/projects\" \"libssl.so,libcrypto.so\""
    echo "示例: $0 \"/home/user/projects\" \"*\"  # 检查所有.so文件"
    exit 1
fi

PROJECT_PATH="$1"
LIBRARY_NAMES="$2"

# 检查readelf是否可用
if ! command -v readelf &> /dev/null; then
    echo -e "${RED}错误: readelf工具未找到，请确保已安装binutils或gcc工具链${NC}"
    exit 1
fi

# 检查项目路径是否存在
if [ ! -d "$PROJECT_PATH" ]; then
    echo -e "${RED}错误: 项目路径 '$PROJECT_PATH' 不存在${NC}"
    exit 1
fi

# 创建临时文件存储结果
TEMP_RESULTS=$(mktemp)
CSV_HEADER="LibraryName,Path,StackProtection,ProtectionLevel,StackChkFail,StackChkGuard"

# 初始化结果数组
declare -a RESULTS=()

# 查找.so文件函数
find_so_files() {
    local found_files=()
    
    if [ "$LIBRARY_NAMES" = "*" ]; then
        echo -e "\n${CYAN}正在搜索所有.so库文件...${NC}"
        while IFS= read -r -d '' file; do
            found_files+=("$file")
        done < <(find "$PROJECT_PATH" -name "*.so" -type f -print0 2>/dev/null)
    else
        # 分割库名列表
        IFS=',' read -ra LIBS <<< "$LIBRARY_NAMES"
        for lib in "${LIBS[@]}"; do
            # 去除空格
            lib=$(echo "$lib" | xargs)
            
            # 确保库文件名以.so结尾
            if [[ ! "$lib" =~ \.so$ ]]; then
                lib="${lib}.so"
            fi
            
            echo -e "\n${CYAN}正在搜索库文件: $lib${NC}"
            while IFS= read -r -d '' file; do
                found_files+=("$file")
            done < <(find "$PROJECT_PATH" -name "$lib" -type f -print0 2>/dev/null)
        done
    fi
    
    # 返回找到的文件（去重）
    printf '%s\n' "${found_files[@]}" | sort -u
}

# 检查栈保护函数
check_stack_protection() {
    local file="$1"
    local filename=$(basename "$file")
    
    echo -e "\n${GREEN}检查文件: $file${NC}"
    
    # 使用readelf检查栈保护符号
    local symbols=$(readelf -s "$file" 2>&1)
    local has_stack_chk_fail=false
    local has_stack_chk_guard=false
    
    if echo "$symbols" | grep -q "__stack_chk_fail"; then
        has_stack_chk_fail=true
    fi
    
    if echo "$symbols" | grep -q "__stack_chk_guard"; then
        has_stack_chk_guard=true
    fi
    
    local protection_status
    if [ "$has_stack_chk_fail" = true ] || [ "$has_stack_chk_guard" = true ]; then
        protection_status="已启用"
    else
        protection_status="未启用"
    fi
    
    # 检查编译选项中的栈保护标志
    local compile_options=$(readelf -p .comment "$file" 2>&1)
    local stack_protector_flag="none"
    
    if echo "$compile_options" | grep -q "\-fstack-protector"; then
        if echo "$compile_options" | grep -q "\-fstack-protector-strong"; then
            stack_protector_flag="strong"
        elif echo "$compile_options" | grep -q "\-fstack-protector-all"; then
            stack_protector_flag="all"
        else
            stack_protector_flag="basic"
        fi
    fi
    
    # 输出状态
    if [ "$protection_status" = "已启用" ]; then
        echo -e "栈保护状态: ${GREEN}$protection_status${NC}"
    else
        echo -e "栈保护状态: ${RED}$protection_status${NC}"
    fi
    echo -e "${CYAN}编译选项: $stack_protector_flag${NC}"
    
    # 保存结果
    local stack_chk_fail_status="缺失"
    local stack_chk_guard_status="缺失"
    
    if [ "$has_stack_chk_fail" = true ]; then
        stack_chk_fail_status="存在"
    fi
    
    if [ "$has_stack_chk_guard" = true ]; then
        stack_chk_guard_status="存在"
    fi
    
    # 将结果添加到数组（CSV格式）
    RESULTS+=("$filename,$file,$protection_status,$stack_protector_flag,$stack_chk_fail_status,$stack_chk_guard_status")
}

# 主执行逻辑
echo "开始检查栈保护状态..."

# 查找文件
mapfile -t FOUND_FILES < <(find_so_files)

# 如果没有找到任何文件
if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}未找到任何.so库文件${NC}"
    exit 0
fi

# 检查每个找到的库文件
for file in "${FOUND_FILES[@]}"; do
    check_stack_protection "$file"
done

# 输出汇总结果
echo -e "\n${MAGENTA}检查结果汇总:${NC}"
printf "%-30s %-15s %-15s %s\n" "LibraryName" "StackProtection" "ProtectionLevel" "Path"
printf "%-30s %-15s %-15s %s\n" "----------" "-------------" "-------------" "----"

for result in "${RESULTS[@]}"; do
    IFS=',' read -ra FIELDS <<< "$result"
    printf "%-30s %-15s %-15s %s\n" "${FIELDS[0]}" "${FIELDS[2]}" "${FIELDS[3]}" "${FIELDS[1]}"
done

# 将结果导出到CSV文件
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
CSV_PATH="stack_protection_report_${TIMESTAMP}.csv"

echo "$CSV_HEADER" > "$CSV_PATH"
printf '%s\n' "${RESULTS[@]}" >> "$CSV_PATH"

echo -e "\n${CYAN}结果已保存到: $CSV_PATH${NC}"

# 统计信息
ENABLED_COUNT=0
TOTAL_COUNT=${#RESULTS[@]}

for result in "${RESULTS[@]}"; do
    IFS=',' read -ra FIELDS <<< "$result"
    if [ "${FIELDS[2]}" = "已启用" ]; then
        ((ENABLED_COUNT++))
    fi
done

if [ $TOTAL_COUNT -gt 0 ]; then
    PERCENTAGE=$(echo "scale=2; $ENABLED_COUNT * 100 / $TOTAL_COUNT" | bc)
else
    PERCENTAGE=0
fi

echo -e "\n${BLUE}统计信息:${NC}"
echo "已检查库文件总数: $TOTAL_COUNT"
echo "启用栈保护的库文件: $ENABLED_COUNT ($PERCENTAGE%)"

# 清理临时文件
rm -f "$TEMP_RESULTS"
