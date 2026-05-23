Youtube视频+中英日字幕+封面TUI下载脚本。

主要基于yt-dlp。

普通版带有环境检测与补齐（仅Debian及其发行版），Lite版无此功能。

支持的功能（带有*号的为Lite版不支持的功能）：

============================

*Python3/pip 自动检测安装

*yt-dlp 自动安装 + 版本检测

*ffmpeg 自动检测安装

*Deno 自动检测安装

SubtitleEditor 自动检测（*安装）

*secretstorage 自动安装

单个/批量下载模式

视频/音频/中英日字幕/封面自由组合

30次重试 + 3-10秒休眠

自动获取Youtube自动字幕，使用SubtitleEditor转换为SRT

Chrome/Firefox/cookies.txt 认证

============================

请使用此命令为此脚本赋予运行权限（Linux）：

    chmod +x YTBDownAllScript.sh
    chmod +x YTBDownAllScript-Lite.sh

然后使用此命令运行此脚本（Linux）：

    ./YTBDownAllScript.sh
    ./YTBDownAllScript-Lite.sh

其全部内容都来自Deepseek生成，无任何人类成分，请不放心使用
