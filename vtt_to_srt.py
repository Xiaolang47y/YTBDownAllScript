#!/usr/bin/env python3
"""
YouTube VTT实时字幕转SRT去重工具 V2.0
功能：将YouTube实时字幕（累积式VTT）转换为去重后的SRT格式
原理：
  1. 过滤掉极短的显示块（<0.1s）
  2. 仅处理带词级时间戳的内容块
  3. 使用累积文本跟踪，提取每个块的新增内容
  4. 智能合并短句块
"""

import re
import sys
import os
from pathlib import Path


def time_to_seconds(time_str):
    """将时间字符串转换为秒"""
    parts = time_str.split(':')
    return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])


def parse_vtt(filepath):
    """解析VTT文件，返回字幕块列表"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 移除WEBVTT头部
    content = re.sub(r'^WEBVTT.*?\n\n', '', content, flags=re.DOTALL)
    
    blocks = []
    # 匹配时间戳和文本块
    pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})[^\n]*\n(.*?)(?=\n\n|\Z)'
    
    for match in re.finditer(pattern, content, re.DOTALL):
        start = match.group(1)
        end = match.group(2)
        text = match.group(3).strip()
        
        # 清理VTT内联标签（如 <c>, <00:00:00.240> 等）
        text = re.sub(r'<\d{2}:\d{2}:\d{2}\.\d{3}>', '', text)
        text = re.sub(r'</?c[^>]*>', '', text)
        text = re.sub(r'<[^>]+>', '', text)
        
        # 清理多余空白
        text = re.sub(r'\s+', ' ', text).strip()
        
        if text:
            duration = time_to_seconds(end) - time_to_seconds(start)
            blocks.append({
                'start': start,
                'end': end,
                'text': text,
                'duration': duration
            })
    
    return blocks


def filter_content_blocks(blocks):
    """过滤掉极短的显示块，保留内容块"""
    content_blocks = []
    for block in blocks:
        # 跳过持续时间小于0.1秒的块（这些是显示块）
        if block['duration'] < 0.1:
            continue
        content_blocks.append(block)
    return content_blocks


def deduplicate_blocks(blocks):
    """去重：从累积文本中提取新增内容"""
    if not blocks:
        return []
    
    result = []
    cumulative_text = ""
    
    for i, block in enumerate(blocks):
        current_text = block['text']
        
        if not cumulative_text:
            # 第一个块，全部是新增内容
            new_block = block.copy()
            new_block['text'] = current_text
            result.append(new_block)
            cumulative_text = current_text
            continue
        
        # 尝试从累积文本中提取新增内容
        new_text = extract_new_text(cumulative_text, current_text)
        
        if new_text and len(new_text) >= 2:
            new_block = block.copy()
            new_block['text'] = new_text
            result.append(new_block)
            cumulative_text = current_text
        else:
            # 没有新增内容或新增内容太少，跳过此块
            cumulative_text = current_text
    
    return result


def extract_new_text(prev_text, current_text):
    """从前一个累积文本和当前文本中提取新增内容"""
    # 方法1：精确前缀匹配
    if current_text.startswith(prev_text):
        new_text = current_text[len(prev_text):].strip()
        return new_text
    
    # 方法2：查找前文在当前位置，提取后续
    if prev_text in current_text:
        idx = current_text.find(prev_text) + len(prev_text)
        new_text = current_text[idx:].strip()
        return new_text
    
    # 方法3：词级重叠检测
    words_prev = prev_text.split()
    words_curr = current_text.split()
    
    if len(words_prev) >= 2 and len(words_curr) >= 2:
        max_overlap = min(len(words_prev), len(words_curr))
        for n in range(max_overlap, 1, -1):
            suffix_words = words_prev[-n:]
            prefix_words = words_curr[:n]
            
            if suffix_words == prefix_words:
                remaining = words_curr[n:]
                if remaining:
                    return ' '.join(remaining)
                return ""
    
    # 方法4：字符级重叠检测
    for overlap_len in range(min(len(prev_text), len(current_text)), 5, -1):
        suffix = prev_text[-overlap_len:]
        if current_text.startswith(suffix):
            new_text = current_text[overlap_len:].strip()
            return new_text
    
    # 无重叠，返回整个当前文本
    return current_text


def merge_short_blocks(blocks, min_duration=0.5):
    """合并过短的字幕块，避免字幕闪得太快"""
    if len(blocks) <= 1:
        return blocks
    
    merged = []
    current = blocks[0].copy()
    
    for i in range(1, len(blocks)):
        next_block = blocks[i]
        
        # 计算当前块持续时间（秒）
        duration = current['duration']
        
        # 如果当前块太短，合并下一个
        if duration < min_duration:
            current['text'] = current['text'] + ' ' + next_block['text']
            current['end'] = next_block['end']
            current['duration'] = time_to_seconds(current['end']) - time_to_seconds(current['start'])
        else:
            merged.append(current)
            current = next_block.copy()
    
    merged.append(current)
    return merged


def clean_text(text):
    """清理文本中的多余空格和标点问题"""
    # 清理多余空格
    text = re.sub(r'\s+', ' ', text).strip()
    
    # 修复标点前的空格
    text = re.sub(r'\s+([,.!?;:])', r'\1', text)
    
    # 修复标点后缺少空格
    text = re.sub(r'([,.!?;:])([a-zA-Z])', r'\1 \2', text)
    
    return text


def vtt_to_srt_time(time_str):
    """将VTT时间格式转换为SRT格式（毫秒3位改逗号）"""
    return time_str.replace('.', ',')


def write_srt(blocks, filepath):
    """写入SRT文件"""
    with open(filepath, 'w', encoding='utf-8') as f:
        for i, block in enumerate(blocks, 1):
            clean_text_content = clean_text(block['text'])
            f.write(f"{i}\n")
            f.write(f"{vtt_to_srt_time(block['start'])} --> {vtt_to_srt_time(block['end'])}\n")
            f.write(f"{clean_text_content}\n\n")


def process_vtt_file(vtt_path, output_path=None):
    """处理单个VTT文件"""
    if output_path is None:
        # 默认输出路径：同名但改为.srt扩展名
        output_path = Path(vtt_path).with_suffix('.srt')
    
    print(f"处理: {vtt_path}")
    
    # 解析VTT
    blocks = parse_vtt(vtt_path)
    if not blocks:
        print(f"  警告: 未找到有效字幕块")
        return False
    
    print(f"  原始块数: {len(blocks)}")
    
    # 过滤显示块
    content_blocks = filter_content_blocks(blocks)
    print(f"  过滤后内容块: {len(content_blocks)}")
    
    # 去重
    deduped = deduplicate_blocks(content_blocks)
    print(f"  去重后: {len(deduped)}")
    
    # 合并过短的块
    merged = merge_short_blocks(deduped)
    print(f"  合并后: {len(merged)}")
    
    # 写入SRT
    write_srt(merged, output_path)
    print(f"  已保存: {output_path}")
    
    return True


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print("用法: python3 vtt_to_srt.py <VTT文件或目录> [输出文件]")
        print("示例:")
        print("  python3 vtt_to_srt.py subtitle.vtt")
        print("  python3 vtt_to_srt.py subtitle.vtt output.srt")
        print("  python3 vtt_to_srt.py /path/to/subtitles/")
        sys.exit(1)
    
    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None
    
    if os.path.isfile(input_path):
        # 处理单个文件
        if output_path and not output_path.endswith('.srt'):
            print("错误: 输出文件必须是.srt格式")
            sys.exit(1)
        process_vtt_file(input_path, output_path)
    elif os.path.isdir(input_path):
        # 批量处理目录中的所有VTT文件
        vtt_files = list(Path(input_path).glob('*.vtt'))
        if not vtt_files:
            print(f"在 {input_path} 中未找到VTT文件")
            sys.exit(1)
        
        print(f"找到 {len(vtt_files)} 个VTT文件\n")
        success = 0
        for vtt_file in vtt_files:
            try:
                if process_vtt_file(str(vtt_file)):
                    success += 1
            except Exception as e:
                print(f"  错误: {e}\n")
        
        print(f"\n完成！成功转换 {success}/{len(vtt_files)} 个文件")
    else:
        print(f"错误: 找不到 {input_path}")
        sys.exit(1)


if __name__ == '__main__':
    main()
