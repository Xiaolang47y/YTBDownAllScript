#!/bin/bash

# ============================================
# YouTube 万能下载器 Lite（批量版）
# 功能：支持单个/批量链接下载，30次重试
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[信息]${NC} $1"; }
warn() { echo -e "${YELLOW}[警告]${NC} $1"; }
error() { echo -e "${RED}[错误]${NC} $1"; }
step() { echo -e "\n${BLUE}>>>${NC} ${BLUE}$1${NC}"; }

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   YouTube 万能下载器 Lite（批量版）   ${NC}"
echo -e "${GREEN}   支持单个/批量 · 25次重试           ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================
# 基础设置
# ============================================
step "1/5 基础设置"

read -p "保存目录（回车使用当前目录）: " SAVE_DIR
if [ -z "$SAVE_DIR" ]; then
    SAVE_DIR="$(pwd)"
fi
mkdir -p "$SAVE_DIR"
cd "$SAVE_DIR"
info "文件将保存到: $SAVE_DIR"

echo ""
echo "认证方式:"
echo "1) 使用 cookies.txt 文件（最稳定）"
echo "2) 从 Firefox 导入 Cookie（推荐）"
echo "3) 从 Chrome 导入 Cookie"
echo "4) 跳过认证"
read -p "请选择 [1-4]: " auth_choice

COOKIE_OPT=""
case $auth_choice in
    1)
        if [ -f "$SAVE_DIR/cookies.txt" ]; then
            COOKIE_OPT="--cookies cookies.txt"
            info "✓ 将使用 cookies.txt"
        else
            warn "未找到 cookies.txt，将跳过认证"
        fi
        ;;
    2)
        COOKIE_OPT="--cookies-from-browser firefox"
        info "✓ 将使用 Firefox Cookie"
        ;;
    3)
        COOKIE_OPT="--cookies-from-browser chrome"
        info "✓ 将使用 Chrome Cookie"
        ;;
    4)
        warn "将跳过认证"
        ;;
esac

# ============================================
# 下载模式选择
# ============================================
step "2/5 选择下载模式"

echo "下载模式:"
echo "1) 单个链接"
echo "2) 批量下载（多个链接）"
read -p "请选择 [1-2]: " batch_mode

# ============================================
# 收集链接
# ============================================
links=()

if [ "$batch_mode" == "2" ]; then
    echo ""
    echo "请输入链接列表（每行一个，输入空行结束）:"
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        links+=("$line")
    done
else
    echo ""
    read -p "👉 请输入 YouTube 链接: " single_url
    links+=("$single_url")
fi

if [ ${#links[@]} -eq 0 ]; then
    error "未输入任何链接！"
    exit 1
fi

# ============================================
# 下载选项（所有链接共用相同选项）
# ============================================
step "3/5 选择下载内容"

read -p "下载视频？(y/n): " get_video
read -p "下载音频？(y/n): " get_audio
read -p "下载字幕？(y/n): " get_sub
read -p "下载封面？(y/n): " get_cover

if [[ "$get_sub" =~ ^[Yy]$ ]]; then
    echo ""
    echo "字幕语言:"
    echo "1) 简体中文"
    echo "2) 英文"
    echo "3) 双语（分开文件）"
    echo "4) 双语（合并为一个文件）"
    read -p "请选择 [1-4]: " lang_choice

    case $lang_choice in
        1) SUB_LANGS="zh-Hans" ; MERGE_SUB=false ;;
        2) SUB_LANGS="en" ; MERGE_SUB=false ;;
        3) SUB_LANGS="zh-Hans,en" ; MERGE_SUB=false ;;
        4) SUB_LANGS="zh-Hans,en" ; MERGE_SUB=true ;;
    esac
fi

# ============================================
# 构建通用命令参数（包含25次重试）
# ============================================
step "4/5 构建下载命令"

# 重试参数（30次，如果不够可改为 infinite）
RETRY_OPTS="--retries 30 --fragment-retries 30 --sleep-interval 3 --max-sleep-interval 10"

BASE_OPTS="$COOKIE_OPT --no-check-certificates $RETRY_OPTS"

if [[ "$get_video" =~ ^[Yy]$ ]]; then
    BASE_OPTS="$BASE_OPTS --format bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
    BASE_OPTS="$BASE_OPTS --merge-output-format mp4"
fi

if [[ "$get_audio" =~ ^[Yy]$ ]]; then
    BASE_OPTS="$BASE_OPTS --extract-audio --audio-format mp3 --audio-quality 0"
fi

if [[ "$get_sub" =~ ^[Yy]$ ]]; then
    BASE_OPTS="$BASE_OPTS --write-subs --write-auto-subs"
    BASE_OPTS="$BASE_OPTS --sub-langs $SUB_LANGS"
    BASE_OPTS="$BASE_OPTS --sub-format srt/best"
    BASE_OPTS="$BASE_OPTS --convert-subs srt"
fi

if [[ "$get_cover" =~ ^[Yy]$ ]]; then
    BASE_OPTS="$BASE_OPTS --write-thumbnail --convert-thumbnails jpg"
fi

if [[ "$get_video" =~ ^[Yy]$ ]] || [[ "$get_audio" =~ ^[Yy]$ ]]; then
    BASE_OPTS="$BASE_OPTS --embed-metadata"
fi

if [[ ! "$get_video" =~ ^[Yy]$ ]] && [[ ! "$get_audio" =~ ^[Yy]$ ]]; then
    BASE_OPTS="$BASE_OPTS --skip-download"
fi

# 显示重试配置
info "重试配置: 最多 25 次（完整下载）/ 25 次（分片下载）"
info "休眠间隔: 5-15 秒"

# ============================================
# 执行下载（循环处理每个链接）
# ============================================
step "5/5 开始下载"

total=${#links[@]}
current=0
success=0
fail=0

for url in "${links[@]}"; do
    current=$((current + 1))
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "正在处理 [$current/$total]: $url"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    yt-dlp $BASE_OPTS -o "%(title)s.%(ext)s" "$url"
    
    if [ $? -eq 0 ]; then
        success=$((success + 1))
        info "✓ 处理成功"
    else
        fail=$((fail + 1))
        warn "✗ 处理失败: $url"
    fi
    
    # 清理临时文件
    rm -f *.vtt 2>/dev/null
    
    # 双语字幕合并（每个视频单独合并）
    if [[ "$MERGE_SUB" == "true" ]]; then
        ZH_FILE=$(ls *.zh-Hans.srt 2>/dev/null | head -1)
        EN_FILE=$(ls *.en.srt 2>/dev/null | head -1)
        if [ -f "$ZH_FILE" ] && [ -f "$EN_FILE" ]; then
            BILINGUAL="${ZH_FILE%.zh-Hans.srt}_bilingual.srt"
            paste -d '\n' "$ZH_FILE" "$EN_FILE" | awk 'NR%2==1 {print; getline; print; getline; print; getline; print ""}' > "$BILINGUAL"
            info "✓ 双语字幕合并完成: $BILINGUAL"
        fi
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}批量下载完成！${NC}"
echo -e "${GREEN}  成功: $success 个${NC}"
echo -e "${GREEN}  失败: $fail 个${NC}"
echo -e "${GREEN}  总计: $total 个链接${NC}"
echo -e "${GREEN}文件保存在: $SAVE_DIR${NC}"
echo -e "${GREEN}========================================${NC}"

if [ $success -gt 0 ]; then
    echo ""
    ls -lh "$SAVE_DIR" | grep -E "\.(mp4|mp3|srt|jpg)$" | tail -15
fi
