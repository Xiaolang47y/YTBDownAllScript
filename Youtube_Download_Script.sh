#!/bin/bash

# 设置颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}      YouTube 智能下载工具 v2.8        ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}请输入 YouTube 视频链接:${NC}"
read -p "👉 " video_url

if [ -z "$video_url" ]; then
    echo -e "${RED}错误：未输入视频链接！${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}开始下载视频...${NC}"
echo ""

yt-dlp \
  --cookies-from-browser firefox \
  --no-check-certificates \
  --extractor-args "youtubetab:skip=authcheck" \
  --format "bestvideo+bestaudio/best" \
  --merge-output-format mkv \
  --write-subs \
  --sub-langs "zh-Hans,en" \
  --write-auto-subs \
  --embed-subs \
  --embed-thumbnail \
  --write-thumbnail \
  --convert-thumbnails jpg \
  --embed-metadata \
  --sleep-interval 30 \
  --max-sleep-interval 60 \
  --sleep-requests 5 \
  --retries 30 \
  --fragment-retries 30 \
  --retry-sleep "exp=1:60:2" \
  -o "%(title)s.%(ext)s" \
  "$video_url"

if [ $? -ne 0 ]; then
    echo -e "${RED}下载失败！请检查网络或视频链接。${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}下载完成！正在转换字幕格式...${NC}"
echo ""

converted_count=0
for vtt_file in *.vtt; do
    if [ -f "$vtt_file" ]; then
        srt_file="${vtt_file%.vtt}.srt"
        ffmpeg -i "$vtt_file" "$srt_file" -loglevel quiet
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ 已转换:${NC} $vtt_file → $srt_file"
            rm -f "$vtt_file"
            ((converted_count++))
        else
            echo -e "${RED}✗ 转换失败:${NC} $vtt_file"
        fi
    fi
done

if [ $converted_count -eq 0 ]; then
    echo -e "${YELLOW}未找到 VTT 字幕文件，可能已经是 SRT 格式或无字幕。${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}所有任务完成！${NC}"
echo -e "${GREEN}输出文件：${NC}"
echo -e "  📹 视频文件: *.mkv"
echo -e "  🖼️ 封面图片: *.jpg"
echo -e "  📝 字幕文件: *.srt (简体中文 & 英文)"
echo -e "${GREEN}========================================${NC}"
