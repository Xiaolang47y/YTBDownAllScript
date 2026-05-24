Youtube视频+中英日字幕+封面TUI下载脚本。

主要基于yt-dlp/python3/ffmpeg。

普通版带有环境检测与补齐（仅Debian及其发行版），Lite版无此功能。

可搭配https://github.com/Xiaolang47y/vtt2srt进行VTT字幕换换SRT字幕，更方便上传B站CC字幕。

支持的功能：

============================

cookies.txt/Firefox/Chrome三种认证方式

单链接下载/批量下载模式

视频下载（MP4最佳画质）

音频提取（MP3最高音质）

VTT字幕下载（支持英/日/简体中文及组合）

通过vtt2srt.py将逐句的VTT格式字幕统一转换为逐句的SRT字幕

封面缩略图下载（JPG）

无限重试下载

============================

请使用此命令为此脚本赋予运行权限（Linux）：

    chmod +x YTBDownAllScript.sh
    chmod +x YTBDownAllScript-Lite.sh

然后使用此命令运行此脚本（Linux）：

    ./YTBDownAllScript.sh
    ./YTBDownAllScript-Lite.sh

其全部内容都来自Deepseek+TRAE AI生成，无任何人类成分，请不放心使用
