#!/bin/bash

# ============================================
# YouTube 万能下载器 Lite V1.0
# 适用于：已安装 yt-dlp / ffmpeg / python3 的环境
# 
# 功能说明：
#   1. 支持 cookies.txt / Firefox / Chrome 三种认证方式
#   2. 单链接下载 / 批量下载模式
#   3. 视频下载（MP4 最佳画质）
#   4. 音频提取（MP3 最高音质）
#   5. VTT 字幕下载（支持英/日/简体中文及组合）
#   6. VTT 转 SRT 智能去重（解决 YouTube 实时字幕累积重复问题）
#   7. 封面缩略图下载（JPG）
#   8. 无限重试机制
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

safe_read() {
    local prompt="$1"
    local var_name="$2"
    local input=""
    while [ -z "$input" ]; do
        read -p "$prompt" input
        if [ -z "$input" ]; then
            warn "输入不能为空，请重新输入"
        fi
    done
    eval "$var_name=\"$input\""
}

safe_option() {
    local prompt="$1"
    local var_name="$2"
    local options="$3"
    local input=""
    while true; do
        read -p "$prompt" input
        if [[ "$options" == *"$input"* ]]; then
            break
        else
            warn "无效选项，请输入 ${options// / 或 } 中的任意一个"
        fi
    done
    eval "$var_name=\"$input\""
}

clear
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   YouTube 万能下载器 Lite V1.0        ${NC}"
echo -e "${GREEN}   VTT字幕去重转SRT · 无限重试         ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================
# 基础设置
# ============================================
DEFAULT_DIR="$(pwd)"
read -p "保存目录（回车使用当前目录）: " SAVE_DIR
[ -z "$SAVE_DIR" ] && SAVE_DIR="$DEFAULT_DIR"
mkdir -p "$SAVE_DIR"
cd "$SAVE_DIR"
info "文件将保存到: $SAVE_DIR"

echo ""
echo "认证方式:"
echo "1) 使用 cookies.txt 文件（最稳定）"
echo "2) 从 Firefox 导入 Cookie（推荐）"
echo "3) 从 Chrome 导入 Cookie"
echo "4) 跳过认证"
safe_option "请选择 [1-4]: " auth_choice "1234"

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
# 下载模式
# ============================================
echo ""
echo "下载模式:"
echo "1) 单个链接"
echo "2) 批量下载"
safe_option "请选择 [1-2]: " batch_mode "12"

links=()
if [ "$batch_mode" == "2" ]; then
    echo "请输入链接列表（每行一个，空行结束）:"
    while IFS= read -r line; do
        [[ -z "$line" ]] && break
        links+=("$line")
    done
else
    safe_read "👉 请输入链接: " single_url
    links+=("$single_url")
fi

# ============================================
# 下载选项
# ============================================
echo ""
echo "下载视频？"
echo "1) 是"
echo "2) 否"
safe_option "请选择 [1-2]: " get_video "12"

echo ""
echo "下载音频？"
echo "1) 是"
echo "2) 否"
safe_option "请选择 [1-2]: " get_audio "12"

echo ""
echo "下载字幕？"
echo "1) 是（VTT 格式，可自动转SRT去重）"
echo "2) 是（直接下载 SRT 格式）"
echo "3) 否"
safe_option "请选择 [1-3]: " get_sub "123"

if [ "$get_sub" == "1" ]; then
    SUB_FORMAT="vtt"
    echo ""
    echo "字幕语言:"
    echo "1) 英语 + 简体中文"
    echo "2) 日语 + 简体中文"
    echo "3) 仅简体中文"
    echo "4) 仅英语"
    echo "5) 仅日语"
    safe_option "请输入 [1-5]: " lang_choice "12345"
    
    case $lang_choice in
        1) SUB_LANGS="en,zh-Hans" ;;
        2) SUB_LANGS="ja,zh-Hans" ;;
        3) SUB_LANGS="zh-Hans" ;;
        4) SUB_LANGS="en" ;;
        5) SUB_LANGS="ja" ;;
    esac
    
    # 检测vtt2srt.py是否存在
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/vtt2srt.py" ]; then
        echo ""
        echo "是否自动转换为SRT（去重）？"
        echo "1) 是（推荐，去除实时字幕重复）"
        echo "2) 否（保留原始VTT）"
        safe_option "请选择 [1-2]: " convert_srt "12"
    else
        warn "未找到 vtt2srt.py，将保留原始VTT格式"
        convert_srt="2"
    fi
elif [ "$get_sub" == "2" ]; then
    SUB_FORMAT="srt"
    echo ""
    echo "字幕语言:"
    echo "1) 英语 + 简体中文"
    echo "2) 日语 + 简体中文"
    echo "3) 仅简体中文"
    echo "4) 仅英语"
    echo "5) 仅日语"
    safe_option "请输入 [1-5]: " lang_choice "12345"
    
    case $lang_choice in
        1) SUB_LANGS="en,zh-Hans" ;;
        2) SUB_LANGS="ja,zh-Hans" ;;
        3) SUB_LANGS="zh-Hans" ;;
        4) SUB_LANGS="en" ;;
        5) SUB_LANGS="ja" ;;
    esac
    
    convert_srt="2"
fi

echo ""
echo "下载封面？"
echo "1) 是"
echo "2) 否"
safe_option "请选择 [1-2]: " get_cover "12"

# ============================================
# 构建下载命令
# ============================================
RETRY_OPTS="--retries infinite --fragment-retries infinite --sleep-interval 3"

BASE_OPTS="$COOKIE_OPT --no-check-certificates $RETRY_OPTS"

if [ "$get_video" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --format bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
    BASE_OPTS="$BASE_OPTS --merge-output-format mp4"
    BASE_OPTS="$BASE_OPTS --embed-metadata"
fi

if [ "$get_audio" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --extract-audio --audio-format mp3 --audio-quality 0"
fi

# 下载字幕
if [ "$get_sub" == "1" ] || [ "$get_sub" == "2" ]; then
    BASE_OPTS="$BASE_OPTS --write-subs --write-auto-subs"
    BASE_OPTS="$BASE_OPTS --sub-langs $SUB_LANGS"
    BASE_OPTS="$BASE_OPTS --sub-format $SUB_FORMAT"
fi

if [ "$get_cover" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --write-thumbnail --convert-thumbnails jpg"
fi

if [ "$get_video" != "1" ] && [ "$get_audio" != "1" ]; then
    BASE_OPTS="$BASE_OPTS --skip-download"
fi

info "重试: 无限重试 · 字幕: VTT 原样下载"
if [ "$get_sub" == "1" ] && [ "$convert_srt" == "1" ]; then
    info "字幕转换: 下载后将统一转换为去重SRT"
fi
echo ""

# ============================================
# 执行下载
# ============================================
total=${#links[@]}
current=0
success=0
fail=0
declare -a download_log

for url in "${links[@]}"; do
    current=$((current + 1))
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    info "[$current/$total] $url"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 重试机制：最多重试3次，应对签名解析错误
    max_retries=3
    retry_count=0
    download_success=false
    video_title=""
    
    while [ $retry_count -lt $max_retries ]; do
        if [ $retry_count -gt 0 ]; then
            warn "第 $retry_count 次重试..."
            sleep 5
        fi
        
        # 下载并输出文件名到变量
        output=$(yt-dlp $BASE_OPTS -o "%(title)s.%(ext)s" --print "%(filename)s" "$url" 2>&1)
        exit_code=$?
        
        if [ $exit_code -eq 0 ]; then
            download_success=true
            # 从输出中提取文件名（最后一行）
            downloaded_file=$(echo "$output" | grep -v "^\[" | grep -v "^WARNING\|^ERROR\|^$" | tail -1)
            if [ -n "$downloaded_file" ]; then
                # 从路径中提取文件名并移除扩展名
                basename_file=$(basename "$downloaded_file")
                video_title="${basename_file%.*}"
            fi
            if [ -z "$video_title" ]; then
                video_title="(未知标题)"
            fi
            break
        fi
        
        retry_count=$((retry_count + 1))
    done
    
    if $download_success; then
        success=$((success + 1))
        info "✓ 下载成功"
        download_log+=("$video_title | $url")
    else
        fail=$((fail + 1))
        warn "✗ 下载失败（已重试 $max_retries 次）"
        download_log+=("[失败] $video_title | $url")
    fi
done

# ============================================
# 统一转换VTT到SRT（去重）
# ============================================
if [ "$get_sub" == "1" ] && [ "$convert_srt" == "1" ]; then
    step "统一转换所有VTT字幕为SRT（去重）"
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    python3 "$SCRIPT_DIR/vtt2srt.py" "$SAVE_DIR"
    info "清理原始VTT文件"
    find "$SAVE_DIR" -name "*.vtt" -type f -delete
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}完成！成功: $success / 失败: $fail${NC}"
echo -e "${GREEN}文件保存在: $SAVE_DIR${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}下载列表:${NC}"
for i in "${!download_log[@]}"; do
    echo "  $((i + 1)). ${download_log[$i]}"
done
