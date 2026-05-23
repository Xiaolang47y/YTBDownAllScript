#!/usr/bin/env python3
"""
YouTube VTT实时字幕转SRT去重工具
功能：将YouTube实时字幕（累积式VTT）转换为去重后的SRT格式
原理：检测累积文本，只保留每段的新增内容
"""

import re
import sys
import os
from pathlib import Path


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
            blocks.append({
                'start': start,
                'end': end,
                'text': text
            })
    
    return blocks


def deduplicate_blocks(blocks):
    """去重：从累积文本中提取新增内容"""
    if not blocks:
        return []
    
    result = []
    prev_text = ""
    
    for i, block in enumerate(blocks):
        current_text = block['text']
        
        if prev_text:
            # 方法1：精确前缀匹配
            if current_text.startswith(prev_text):
                new_text = current_text[len(prev_text):].strip()
                if len(new_text) < 2:
                    continue
                result.append({
                    'start': block['start'],
                    'end': block['end'],
                    'text': new_text
                })
                prev_text = current_text
                continue
            
            # 方法2：查找前文在当前位置，提取后续
            if prev_text in current_text:
                idx = current_text.find(prev_text) + len(prev_text)
                new_text = current_text[idx:].strip()
                if len(new_text) < 2:
                    continue
                result.append({
                    'start': block['start'],
                    'end': block['end'],
                    'text': new_text
                })
                prev_text = current_text
                continue
            
            # 方法3：查找重叠部分（前文的结尾与当前文本的开头重叠）
            overlap_found = False
            for overlap_len in range(min(len(prev_text), len(current_text)), 10, -1):
                suffix = prev_text[-overlap_len:]
                if current_text.startswith(suffix):
                    # 找到重叠，提取非重叠部分
                    new_text = current_text[overlap_len:].strip()
                    if len(new_text) >= 2:
                        result.append({
                            'start': block['start'],
                            'end': block['end'],
                            'text': new_text
                        })
                    overlap_found = True
                    break
            
            if overlap_found:
                prev_text = current_text
                continue
            
            # 方法4：查找前文后半部分在当前的开头（更宽松的重叠检测）
            words_prev = prev_text.split()
            words_curr = current_text.split()
            
            if len(words_prev) >= 3 and len(words_curr) >= 3:
                for n in range(min(len(words_prev), len(words_curr)), 1, -1):
                    suffix_words = ' '.join(words_prev[-n:])
                    prefix_words = ' '.join(words_curr[:n])
                    
                    if suffix_words == prefix_words:
                        # 找到词级重叠
                        remaining = words_curr[n:]
                        if remaining:
                            new_text = ' '.join(remaining)
                            if len(new_text) >= 2:
                                result.append({
                                    'start': block['start'],
                                    'end': block['end'],
                                    'text': new_text
                                })
                        overlap_found = True
                        break
            
            if overlap_found:
                prev_text = current_text
                continue
            
            # 无重叠，全新内容
            result.append({
                'start': block['start'],
                'end': block['end'],
                'text': current_text
            })
        else:
            # 第一个块
            result.append({
                'start': block['start'],
                'end': block['end'],
                'text': current_text
            })
        
        prev_text = current_text
    
    return result


def merge_short_blocks(blocks, min_duration=1.5):
    """合并过短的字幕块，避免字幕闪得太快"""
    if len(blocks) <= 1:
        return blocks
    
    merged = []
    current = blocks[0].copy()
    
    for i in range(1, len(blocks)):
        next_block = blocks[i]
        
        # 计算当前块持续时间（秒）
        start_parts = current['start'].split(':')
        end_parts = current['end'].split(':')
        
        start_sec = float(start_parts[0]) * 3600 + float(start_parts[1]) * 60 + float(start_parts[2])
        end_sec = float(end_parts[0]) * 3600 + float(end_parts[1]) * 60 + float(end_parts[2])
        duration = end_sec - start_sec
        
        # 如果当前块太短，合并下一个
        if duration < min_duration:
            current['text'] = current['text'] + ' ' + next_block['text']
            current['end'] = next_block['end']
        else:
            merged.append(current)
            current = next_block.copy()
    
    merged.append(current)
    return merged


def vtt_to_srt_time(time_str):
    """将VTT时间格式转换为SRT格式（毫秒3位改逗号）"""
    return time_str.replace('.', ',')


def write_srt(blocks, filepath):
    """写入SRT文件"""
    with open(filepath, 'w', encoding='utf-8') as f:
        for i, block in enumerate(blocks, 1):
            f.write(f"{i}\n")
            f.write(f"{vtt_to_srt_time(block['start'])} --> {vtt_to_srt_time(block['end'])}\n")
            f.write(f"{block['text']}\n\n")


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
    
    # 去重
    deduped = deduplicate_blocks(blocks)
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
