#!/usr/bin/env python3
"""
KOReader .sdr Metadata Parser
Extracts actual highlights and notes from KOReader .sdr metadata files.
This is where the real highlight content is stored, not in the database.
"""

import os
import re
import json
import argparse
from pathlib import Path
from datetime import datetime

def parse_lua_table_simple(content):
    """Simple Lua table parser for KOReader metadata."""
    
    # Extract annotations section (KOReader uses "annotations" not "highlight")
    annotations_match = re.search(r'\["annotations"\]\s*=\s*{(.*?)(?=\n\s*\[|\n\s*})', content, re.DOTALL)
    if not annotations_match:
        # Try alternative structure
        highlight_match = re.search(r'\["highlight"\]\s*=\s*{(.*?)(?=\n\s*\[|\n\s*})', content, re.DOTALL)
        if not highlight_match:
            return []
        annotations_content = highlight_match.group(1)
    else:
        annotations_content = annotations_match.group(1)
    
    # Find individual annotation entries
    annotation_pattern = r'\[(\d+)\]\s*=\s*{(.*?)(?=\n\s*\[\d+\]|\n\s*})'
    annotation_matches = re.findall(annotation_pattern, annotations_content, re.DOTALL)
    
    highlights = []
    for match in annotation_matches:
        entry_num, entry_content = match
        
        # Extract fields from the annotation entry
        highlight_data = {}
        
        # Text content
        text_match = re.search(r'\["text"\]\s*=\s*"(.*?)"', entry_content, re.DOTALL)
        if text_match:
            highlight_data['text'] = text_match.group(1).replace('\\"', '"').replace('\\n', '\n')
        
        # Chapter/section
        chapter_match = re.search(r'\["chapter"\]\s*=\s*"(.*?)"', entry_content, re.DOTALL)
        if chapter_match:
            highlight_data['chapter'] = chapter_match.group(1).replace('\\"', '"')
        
        # Note
        note_match = re.search(r'\["note"\]\s*=\s*"(.*?)"', entry_content, re.DOTALL)
        if note_match:
            highlight_data['note'] = note_match.group(1).replace('\\"', '"')
        
        # Page
        page_match = re.search(r'\["pageno"\]\s*=\s*(\d+)', entry_content)
        if page_match:
            highlight_data['page'] = int(page_match.group(1))
        
        # Datetime
        datetime_match = re.search(r'\["datetime"\]\s*=\s*"(.*?)"', entry_content)
        if datetime_match:
            highlight_data['datetime'] = datetime_match.group(1)
        
        if highlight_data.get('text'):  # Only include if we found text
            highlights.append(highlight_data)
    
    return highlights

def extract_highlights_from_sdr(books_dir):
    """Extract highlights from all .sdr directories in books folder."""
    
    books_dir = Path(books_dir)
    if not books_dir.exists():
        print(f"Error: Books directory not found: {books_dir}")
        return
    
    results = {}
    
    # Find all .sdr directories
    sdr_dirs = list(books_dir.glob('*.sdr'))
    
    if not sdr_dirs:
        print("No .sdr directories found. Make sure you're pointing to the correct books directory.")
        return
    
    print(f"Found {len(sdr_dirs)} .sdr directories")
    
    for sdr_dir in sdr_dirs:
        book_name = sdr_dir.name.replace('.sdr', '')
        metadata_file = sdr_dir / 'metadata.epub.lua'
        
        if not metadata_file.exists():
            print(f"⚠️  No metadata file found for {book_name}")
            continue
        
        try:
            with open(metadata_file, 'r', encoding='utf-8') as f:
                content = f.read()
            
            highlights = parse_lua_table_simple(content)
            
            if highlights:
                results[book_name] = {
                    'title': book_name,
                    'highlight_count': len(highlights),
                    'highlights': highlights
                }
                
                print(f"\n📚 {book_name}")
                print(f"   Found {len(highlights)} highlights")
                
                # Show first few highlights as preview
                for i, highlight in enumerate(highlights[:3]):
                    print(f"   🔖 {i+1}: {highlight.get('text', '')[:100]}...")
                    if highlight.get('note'):
                        print(f"      💭 Note: {highlight['note']}")
                
                if len(highlights) > 3:
                    print(f"   ... and {len(highlights) - 3} more highlights")
            else:
                print(f"📖 {book_name}: No highlights found")
                
        except Exception as e:
            print(f"❌ Error parsing {book_name}: {e}")
    
    return results

def export_highlights(results, format='json', output_file=None):
    """Export highlights in various formats."""
    
    if not results:
        print("No highlights to export.")
        return
    
    if format == 'json':
        output_file = output_file or 'highlights_export.json'
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=2, ensure_ascii=False)
        print(f"\n💾 Highlights exported to {output_file}")
    
    elif format == 'markdown':
        output_file = output_file or 'highlights_export.md'
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("# KOReader Highlights Export\n\n")
            f.write(f"Exported on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            
            for book_name, book_data in results.items():
                f.write(f"## {book_data['title']}\n\n")
                f.write(f"**Total Highlights:** {book_data['highlight_count']}\n\n")
                
                for i, highlight in enumerate(book_data['highlights'], 1):
                    f.write(f"### Highlight {i}\n\n")
                    if highlight.get('chapter'):
                        f.write(f"**Chapter:** {highlight['chapter']}\n\n")
                    if highlight.get('page'):
                        f.write(f"**Page:** {highlight['page']}\n\n")
                    
                    f.write(f"> {highlight.get('text', '')}\n\n")
                    
                    if highlight.get('note'):
                        f.write(f"**Note:** {highlight['note']}\n\n")
                    
                    if highlight.get('datetime'):
                        f.write(f"*Added: {highlight['datetime']}*\n\n")
                    
                    f.write("---\n\n")
        
        print(f"\n💾 Highlights exported to {output_file}")

def main():
    parser = argparse.ArgumentParser(description='Extract highlights from KOReader .sdr metadata files')
    parser.add_argument('books_dir', help='Path to books directory containing .sdr folders')
    parser.add_argument('--format', choices=['json', 'markdown'], default='markdown',
                       help='Export format (default: markdown)')
    parser.add_argument('--output', help='Output file name')
    parser.add_argument('--book', help='Extract highlights for specific book only')
    
    args = parser.parse_args()
    
    print("📚 KOReader Highlights Extractor")
    print("=" * 50)
    print("Extracting from .sdr metadata files...")
    
    # Extract highlights
    results = extract_highlights_from_sdr(args.books_dir)
    
    # Filter by specific book if requested
    if args.book and results:
        filtered_results = {}
        for book_name, book_data in results.items():
            if args.book.lower() in book_name.lower():
                filtered_results[book_name] = book_data
        results = filtered_results
    
    # Export results
    if results:
        export_highlights(results, args.format, args.output)
        
        total_highlights = sum(book['highlight_count'] for book in results.values())
        print(f"\n✅ Successfully extracted {total_highlights} highlights from {len(results)} books!")
    else:
        print("\n❌ No highlights found. Check that:")
        print("   - Books directory path is correct")
        print("   - .sdr directories exist (created by KOReader)")
        print("   - You have made highlights in KOReader")

if __name__ == '__main__':
    main()