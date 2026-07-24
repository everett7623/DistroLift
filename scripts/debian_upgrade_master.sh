#!/bin/bash

# Debian分版本升级主控脚本
# 版本: 2.0
# 功能：自动下载并执行对应版本的升级脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# GitHub仓库信息（需要修改为实际的仓库地址）
GITHUB_REPO="everett7623/DistroLift"
GITHUB_BRANCH="main"
GITHUB_RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $1"
}

# 检测当前Debian版本
get_current_version() {
    local version=""
    
    if [[ -f /etc/debian_version ]]; then
        local content=$(cat /etc/debian_version)
        case "$content" in
            8.*|jessie*) version="8" ;;
            9.*|stretch*) version="9" ;;
            10.*|buster*) version="10" ;;
            11.*|bullseye*) version="11" ;;
            12.*|bookworm*) version="12" ;;
            13.*|trixie*) version="13" ;;
            *) version="" ;;
        esac
    fi
    
    if [[ -z "$version" ]] && [[ -f /etc/os-release ]]; then
        version=$(grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2 2>/dev/null || echo "")
    fi
    
    echo "$version"
}

# 获取版本信息
get_version_info() {
    case $1 in
        "8") echo "Debian 8 (Jessie) - 已停止支持" ;;
        "9") echo "Debian 9 (Stretch) - 旧版本" ;;
        "10") echo "Debian 10 (Buster) - 旧稳定版" ;;
        "11") echo "Debian 11 (Bullseye) - 旧稳定版" ;;
        "12") echo "Debian 12 (Bookworm) - 当前稳定版 ✅" ;;
        "13") echo "Debian 13 (Trixie) - 测试版 ⚠️" ;;
        *) echo "未知版本" ;;
    esac
}

# 显示升级路径
show_upgrade_path() {
    local current=$1
    echo
    echo "📊 可用的升级路径："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    case $current in
        "8")
            echo "  8 → 9 → 10 → 11 → 12 (推荐停在12)"
            echo "  当前: Debian 8 (需要逐步升级)"
            ;;
        "9")
            echo "  9 → 10 → 11 → 12 (推荐停在12)"
            echo "  当前: Debian 9 (需要逐步升级)"
            ;;
        "10")
            echo "  10 → 11 → 12 (推荐停在12)"
            echo "  当前: Debian 10 (需要逐步升级)"
            ;;
        "11")
            echo "  11 → 12 (推荐)"
            echo "  当前: Debian 11 (建议升级到12)"
            ;;
        "12")
            echo "  12 → 13 (不推荐，测试版本)"
            echo "  当前: Debian 12 (已是稳定版 ✅)"
            ;;
        "13")
            echo "  已是最新测试版本"
            ;;
        *)
            echo "  无法确定升级路径"
            ;;
    esac
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 下载升级脚本
download_script() {
    local from_version=$1
    local to_version=$2
    local script_name="debian_${from_version}to${to_version}_upgrade.sh"
    local script_url="$GITHUB_RAW_URL/scripts/$script_name"
    
    log_info "下载升级脚本: $script_name"
    
    # 使用本地脚本（如果存在）
    if [[ -f "/usr/local/bin/$script_name" ]]; then
        log_info "使用本地脚本: /usr/local/bin/$script_name"
        cp "/usr/local/bin/$script_name" "/tmp/$script_name"
        chmod +x "/tmp/$script_name"
        return 0
    fi
    
    # 尝试从GitHub下载
    if command -v wget >/dev/null 2>&1; then
        wget -q -O "/tmp/$script_name" "$script_url" 2>/dev/null || {
            log_error "无法下载脚本: $script_url"
            return 1
        }
    elif command -v curl >/dev/null 2>&1; then
        curl -s -o "/tmp/$script_name" "$script_url" 2>/dev/null || {
            log_error "无法下载脚本: $script_url"
            return 1
        }
    else
        log_error "需要wget或curl来下载脚本"
        return 1
    fi
    
    chmod +x "/tmp/$script_name"
    log_success "脚本下载成功"
    return 0
}

# 执行单步升级
perform_single_upgrade() {
    local from_version=$1
    local to_version=$2
    local script_name="debian_${from_version}to${to_version}_upgrade.sh"
    
    log_info "准备从 Debian $from_version 升级到 Debian $to_version"
    
    if download_script "$from_version" "$to_version"; then
        log_info "执行升级脚本..."
        "/tmp/$script_name"
        rm -f "/tmp/$script_name"
        return $?
    else
        log_error "无法获取升级脚本"
        return 1
    fi
}

# 批量升级模式
batch_upgrade() {
    local current_version=$1
    local target_version=$2
    local upgrade_path=()
    
    # 构建升级路径
    local v=$current_version
    while [[ $v -lt $target_version ]]; do
        upgrade_path+=($v)
        ((v++))
    done
    upgrade_path+=($target_version)
    
    echo
    log_info "批量升级计划："
    log_info "升级路径: ${upgrade_path[*]}"
    log_info "共需要 $((${#upgrade_path[@]} - 1)) 步升级"
    echo
    
    read -p "是否继续批量升级? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "批量升级已取消"
        return 1
    fi
    
    # 执行升级
    for ((i=0; i<$((${#upgrade_path[@]} - 1)); i++)); do
        local from="${upgrade_path[$i]}"
        local to="${upgrade_path[$((i+1))]}"
        
        echo
        log_info "步骤 $((i+1))/$((${#upgrade_path[@]} - 1)): Debian $from → $to"
        
        if ! perform_single_upgrade "$from" "$to"; then
            log_error "升级失败，停止批量升级"
            return 1
        fi
        
        # 检查是否需要重启
        local new_version=$(get_current_version)
        if [[ "$new_version" == "$to" ]]; then
            log_success "成功升级到 Debian $to"
            
            if [[ $((i+1)) -lt $((${#upgrade_path[@]} - 1)) ]]; then
                echo
                log_warning "需要重启系统后继续下一步升级"
                log_info "重启后运行: $0 --batch $target_version"
                return 0
            fi
        else
            log_error "升级验证失败"
            return 1
        fi
    done
    
    log_success "批量升级完成！"
}

# 显示帮助
show_help() {
    cat << EOF
Debian分版本升级主控脚本 v2.0

📖 用法: $0 [选项]

🔧 选项:
  -h, --help              显示此帮助信息
  -c, --check             检查当前版本和可用升级
  -s, --single <版本>     单步升级到下一个版本
  -b, --batch <版本>      批量升级到指定版本
  -l, --list              列出所有可用的升级脚本
  --fix                   下载并运行修复脚本
  
✨ 功能特性:
  ✅ 自动检测当前版本
  ✅ 分版本独立升级脚本
  ✅ 支持单步和批量升级
  ✅ 针对各版本特定问题优化
  ✅ 完整的错误处理和回滚支持

🔄 使用示例:
  $0 --check              # 检查当前版本
  $0 --single 11          # 从10升级到11
  $0 --batch 12           # 批量升级到12
  
📋 升级建议:
  • Debian 8-9: 已停止支持，建议尽快升级
  • Debian 10-11: 旧版本，建议升级到12
  • Debian 12: 当前稳定版，推荐使用
  • Debian 13: 测试版本，不建议生产使用

⚠️  注意事项:
  • 升级前务必备份重要数据
  • 确保有控制台访问权限
  • 每次升级后建议重启系统
  • 不要跳级升级

🔧 故障排除:
  • 如果下载脚本失败，可以手动下载到 /usr/local/bin/
  • 升级失败时，检查 /root/debian_upgrade_backup_* 目录
  • 使用各版本脚本中的修复功能
EOF
}

# 列出可用脚本
list_scripts() {
    echo "📋 可用的升级脚本："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  • debian_8to9_upgrade.sh   - Debian 8 → 9"
    echo "  • debian_9to10_upgrade.sh  - Debian 9 → 10"
    echo "  • debian_10to11_upgrade.sh - Debian 10 → 11 (增强版)"
    echo "  • debian_11to12_upgrade.sh - Debian 11 → 12 (修复重启)"
    echo "  • debian_12to13_upgrade.sh - Debian 12 → 13 (测试版)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "💡 脚本位置："
    echo "  • 在线: $GITHUB_RAW_URL/scripts/"
    echo "  • 本地: /usr/local/bin/"
}

# 检查系统
check_system() {
    local current_version=$(get_current_version)
    
    echo "========================================="
    echo "🔍 Debian系统检查"
    echo "========================================="
    
    if [[ -z "$current_version" ]]; then
        log_error "无法检测Debian版本"
        log_info "请确保这是Debian系统"
        exit 1
    fi
    
    local version_info=$(get_version_info "$current_version")
    echo "当前版本: $version_info"
    
    # 显示系统信息
    echo
    echo "📊 系统信息:"
    echo "  内核: $(uname -r)"
    echo "  架构: $(dpkg --print-architecture)"
    echo "  主机: $(hostname)"
    
    # 显示升级路径
    show_upgrade_path "$current_version"
    
    # 给出建议
    echo
    echo "💡 建议:"
    case $current_version in
        "8"|"9"|"10"|"11")
            echo "  推荐升级到 Debian 12 (稳定版)"
            echo "  命令: $0 --batch 12"
            ;;
        "12")
            echo "  您已在使用当前稳定版 ✅"
            echo "  保持当前版本即可"
            ;;
        "13")
            echo "  您在使用测试版本 ⚠️"
            echo "  注意系统稳定性"
            ;;
    esac
    echo "========================================="
}

# 主函数
main() {
    # 检查root权限
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本必须以root权限运行"
        exit 1
    fi
    
    # 解析参数
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            check_system
            exit 0
            ;;
        -l|--list)
            list_scripts
            exit 0
            ;;
        -s|--single)
            if [[ -z "${2:-}" ]]; then
                log_error "请指定目标版本"
                exit 1
            fi
            current_version=$(get_current_version)
            target_version=$2
            next_version=$((current_version + 1))
            
            if [[ "$target_version" != "$next_version" ]]; then
                log_error "单步升级只能升级到下一个版本 (Debian $next_version)"
                exit 1
            fi
            
            perform_single_upgrade "$current_version" "$target_version"
            ;;
        -b|--batch)
            if [[ -z "${2:-}" ]]; then
                log_error "请指定目标版本"
                exit 1
            fi
            current_version=$(get_current_version)
            target_version=$2
            
            if [[ "$target_version" -le "$current_version" ]]; then
                log_error "目标版本必须高于当前版本"
                exit 1
            fi
            
            if [[ "$target_version" -gt 13 ]]; then
                log_error "目标版本无效"
                exit 1
            fi
            
            batch_upgrade "$current_version" "$target_version"
            ;;
        --fix)
            log_info "下载修复脚本..."
            wget -O /tmp/debian_fix.sh "$GITHUB_RAW_URL/scripts/debian_fix.sh" || {
                log_error "无法下载修复脚本"
                exit 1
            }
            chmod +x /tmp/debian_fix.sh
            /tmp/debian_fix.sh
            rm -f /tmp/debian_fix.sh
            ;;
        "")
            # 默认行为：检查并提示
            check_system
            ;;
        *)
            log_error "未知选项: $1"
            echo "使用 '$0 --help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
