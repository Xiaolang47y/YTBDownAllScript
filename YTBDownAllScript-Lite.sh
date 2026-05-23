#!/bin/bash

# ============================================
# YouTube 万能下载器 Lite V16.5
# 适用于：Debian / Ubuntu / Linux Mint 等 Debian 系列发行版
# 
# 功能说明：
#   1. 无环境检测（需预先安装 yt-dlp/ffmpeg）
#   2. 支持单个链接或批量链接下载
#   3. 支持视频/音频/字幕/封面自由组合
#   4. 字幕支持英语/日语 + 简体中文
#   5. 智能合并碎句字幕（针对逐词模式优化）
#   6. 无限重试 · 全数字输入
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
echo -e "${GREEN}   YouTube 万能下载器 Lite V16.5      ${NC}"
echo -e "${GREEN}   智能字幕合并 · 逐词模式适配       ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# ============================================
# 基础设置
# ============================================
step "1/4 基础设置"

DEFAULT_DIR="$(pwd)"
read -p "保存目录（回车使用当前目录: $DEFAULT_DIR）: " SAVE_DIR
if [ -z "$SAVE_DIR" ]; then
    SAVE_DIR="$DEFAULT_DIR"
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
# 下载模式选择
# ============================================
echo ""
echo "下载模式:"
echo "1) 单个链接"
echo "2) 批量下载（多个链接）"
safe_option "请选择 [1-2]: " batch_mode "12"

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
    safe_read "👉 请输入 YouTube 链接: " single_url
    links+=("$single_url")
fi

if [ ${#links[@]} -eq 0 ]; then
    error "未输入任何链接！"
    exit 1
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
echo "1) 是"
echo "2) 否"
safe_option "请选择 [1-2]: " get_sub "12"

echo ""
echo "下载封面？"
echo "1) 是"
echo "2) 否"
safe_option "请选择 [1-2]: " get_cover "12"

if [ "$get_sub" == "1" ]; then
    echo ""
    echo "请选择字幕语言:"
    echo "1) 英语 + 简体中文"
    echo "2) 日语 + 简体中文"
    echo "3) 仅简体中文"
    echo "4) 仅英语"
    echo "5) 仅日语"
    safe_option "请输入数字 [1-5]: " lang_choice "12345"

    case $lang_choice in
        1) SOURCE_LANG="en" ; TARGET_LANG="zh-Hans" ;;
        2) SOURCE_LANG="ja" ; TARGET_LANG="zh-Hans" ;;
        3) SOURCE_LANG=""    ; TARGET_LANG="zh-Hans" ;;
        4) SOURCE_LANG="en"  ; TARGET_LANG="" ;;
        5) SOURCE_LANG="ja"  ; TARGET_LANG="" ;;
    esac
fi

# ============================================
# 构建命令参数（无限重试）
# ============================================
step "2/4 构建下载命令"

RETRY_OPTS="--retries infinite --fragment-retries infinite --sleep-interval 3 --max-sleep-interval 10"

BASE_OPTS="$COOKIE_OPT --no-check-certificates $RETRY_OPTS"

if [ "$get_video" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --format bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
    BASE_OPTS="$BASE_OPTS --merge-output-format mp4"
fi

if [ "$get_audio" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --extract-audio --audio-format mp3 --audio-quality 0"
fi

if [ "$get_sub" == "1" ]; then
    SUB_LANGS=""
    if [ -n "$SOURCE_LANG" ]; then
        SUB_LANGS="$SOURCE_LANG"
    fi
    if [ -n "$TARGET_LANG" ]; then
        if [ -n "$SUB_LANGS" ]; then
            SUB_LANGS="$SUB_LANGS,$TARGET_LANG"
        else
            SUB_LANGS="$TARGET_LANG"
        fi
    fi
    
    BASE_OPTS="$BASE_OPTS --write-subs --write-auto-subs"
    BASE_OPTS="$BASE_OPTS --sub-langs $SUB_LANGS"
    BASE_OPTS="$BASE_OPTS --sub-format vtt"
fi

if [ "$get_cover" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --write-thumbnail --convert-thumbnails jpg"
fi

if [ "$get_video" == "1" ] || [ "$get_audio" == "1" ]; then
    BASE_OPTS="$BASE_OPTS --embed-metadata"
fi

if [ "$get_video" != "1" ] && [ "$get_audio" != "1" ]; then
    BASE_OPTS="$BASE_OPTS --skip-download"
fi

info "重试配置: 无限重试（网络波动自动恢复）"
info "休眠间隔: 3-10 秒"
echo ""

# ============================================
# 智能字幕合并函数（针对逐词模式优化）
# ============================================
merge_subtitle() {
    local input_srt="$1"
    local temp_file="${input_srt}.tmp"
    local merged_file="${input_srt}.merged"
    
    if [ ! -s "$input_srt" ]; then
        return 1
    fi
    
    # 步骤1：去除完全重复的行
    awk '
    BEGIN { prev_text = ""; output_count = 0; }
    {
        if (NF == 0) next;
        
        if ($0 ~ /-->/) {
            time_line = $0
            getline text_line
            getline
            text_line = text_line
            
            if (text_line != prev_text) {
                output_count++
                print output_count
                print time_line
                print text_line
                print ""
                prev_text = text_line
            }
        }
    }
    ' "$input_srt" > "$temp_file"
    
    # 步骤2：基于语义合并短句
    awk '
    function time_to_seconds(t) {
        split(t, parts, /[:,]/)
        if (parts[4] == "") parts[4] = 0
        return parts[1]*3600 + parts[2]*60 + parts[3] + parts[4]/1000
    }
    
    BEGIN { 
        merged_text = ""; 
        merged_start = ""; 
        merged_end = "";
        last_end_sec = 0;
        output_count = 0;
    }
    
    {
        if (NF == 0) next;
        
        if ($0 ~ /^[0-9]+$/) {
            getline time_line
            getline text_line
            getline
            
            split(time_line, time_arr, " --> ")
            start_time = time_arr[1]
            end_time = time_arr[2]
            
            start_sec = time_to_seconds(start_time)
            end_sec = time_to_seconds(end_time)
            text_len = length(text_line)
            
            has_end = (text_line ~ /[.!?…]$/)
            
            if (merged_text == "") {
                merged_text = text_line
                merged_start = start_time
                merged_end = end_time
                last_end_sec = end_sec
                has_end_mark = has_end
            } else {
                gap = start_sec - last_end_sec
                
                should_merge = 0
                if (gap < 1.0 && !has_end_mark) {
                    should_merge = 1
                } else if (text_len < 30 && !has_end && !has_end_mark) {
                    should_merge = 1
                } else if (gap < 2.0 && text_len < 40 && !has_end) {
                    should_merge = 1
                }
                
                if (should_merge) {
                    merged_text = merged_text " " text_line
                    merged_end = end_time
                    last_end_sec = end_sec
                    has_end_mark = has_end
                } else {
                    output_count++
                    print output_count
                    print merged_start " --> " merged_end
                    if (merged_text !~ /[.!?…]$/ && length(merged_text) > 20) {
                        merged_text = merged_text "."
                    }
                    print merged_text
                    print ""
                    
                    merged_text = text_line
                    merged_start = start_time
                    merged_end = end_time
                    last_end_sec = end_sec
                    has_end_mark = has_end
                }
            }
        }
    }
    END {
        if (merged_text != "") {
            output_count++
            print output_count
            print merged_start " --> " merged_end
            if (merged_text !~ /[.!?…]$/ && length(merged_text) > 20) {
                merged_text = merged_text "."
            }
            print merged_text
            print ""
        }
    }
    ' "$temp_file" > "$merged_file"
    
    if [ -s "$merged_file" ]; then
        mv "$merged_file" "$input_srt"
        rm -f "$temp_file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# ============================================
# 执行下载
# ============================================
step "3/4 开始下载"

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
        info "✓ 下载成功"
        
        # ============================================
        # 字幕处理：VTT → SRT → 智能合并
        # ============================================
        if [ "$get_sub" == "1" ]; then
            for vtt_file in *.vtt; do
                if [ -f "$vtt_file" ]; then
                    srt_file="${vtt_file%.vtt}.srt"
                    
                    info "正在处理字幕: $(basename "$vtt_file")"
                    
                    ffmpeg -i "$vtt_file" "$srt_file" -loglevel quiet 2>/dev/null
                    if [ $? -eq 0 ]; then
                        rm -f "$vtt_file"
                        info "✓ 已转换: $(basename "$vtt_file") → $(basename "$srt_file")"
                        
                        info "正在合并碎句字幕..."
                        if merge_subtitle "$srt_file"; then
                            info "✓ 已合并碎句: $(basename "$srt_file")"
                        else
                            warn "碎句合并失败: $(basename "$srt_file")"
                        fi
                    else
                        warn "转换失败: $vtt_file"
                    fi
                fi
            done
        fi
        
        # 清理残留
        rm -f *.vtt 2>/dev/null
        rm -f *.tmp 2>/dev/null
        
    else
        fail=$((fail + 1))
        warn "✗ 处理失败: $url"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}下载完成！${NC}"
echo -e "${GREEN}  成功: $success 个${NC}"
echo -e "${GREEN}  失败: $fail 个${NC}"
echo -e "${GREEN}  总计: $total 个链接${NC}"
echo -e "${GREEN}文件保存在: $SAVE_DIR${NC}"
echo -e "${GREEN}========================================${NC}"

if [ $success -gt 0 ]; then
    echo ""
    ls -lh "$SAVE_DIR" | grep -E "\.(mp4|mp3|srt|jpg)$" | tail -15
fi