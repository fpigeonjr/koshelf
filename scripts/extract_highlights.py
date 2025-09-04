#!/usr/bin/env python3
"""
KOReader Highlights Extractor
Extracts highlights and notes from KOReader statistics database for journal workflow.
"""

import sqlite3
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

def extract_highlights(db_path, output_format='text', book_filter=None):
    """Extract highlights from KOReader statistics database."""
    
    if not Path(db_path).exists():
        print(f"Error: Database not found at {db_path}")
        return
    
    conn = None
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check what tables exist
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [row[0] for row in cursor.fetchall()]
        print(f"Available tables: {', '.join(tables)}")
        
        # Get books with highlights
        query = """
        SELECT id, title, authors, highlights, notes, total_read_time, total_read_pages
        FROM book 
        WHERE highlights > 0 OR notes > 0
        ORDER BY title
        """
        
        if book_filter:
            query = query.replace("WHERE", f"WHERE (title LIKE '%{book_filter}%' OR authors LIKE '%{book_filter}%') AND")
        
        cursor.execute(query)
        books = cursor.fetchall()
        
        if not books:
            print("No books with highlights/notes found.")
            return
        
        results = []
        
        for book_id, title, authors, highlight_count, note_count, read_time, read_pages in books:
            book_data = {
                'id': book_id,
                'title': title,
                'authors': authors,
                'highlight_count': highlight_count,
                'note_count': note_count,
                'read_time': read_time,
                'read_pages': read_pages,
                'highlights': [],
                'notes': []
            }
            
            # Note: KOReader stores actual highlight content in .sdr metadata files, 
            # not in the statistics database. The database only contains counts.
            print(f"\n📚 {title}")
            print(f"   Author(s): {authors}")
            print(f"   Highlights: {highlight_count}")
            print(f"   Notes: {note_count}")
            if read_time:
                hours = read_time // 3600
                minutes = (read_time % 3600) // 60
                print(f"   Reading time: {hours}h {minutes}m")
            
            results.append(book_data)
        
        # Output results
        if output_format == 'json':
            output_file = 'koreader_highlights.json'
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(results, f, indent=2, ensure_ascii=False)
            print(f"\n💾 Results saved to {output_file}")
        
        return results
        
    except sqlite3.Error as e:
        print(f"Database error: {e}")
    finally:
        if conn:
            conn.close()

def extract_reading_stats(db_path):
    """Extract reading statistics for additional insights."""
    
    conn = None
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Get page statistics
        cursor.execute("""
        SELECT 
            strftime('%Y-%m-%d', datetime(start_time, 'unixepoch')) as date,
            SUM(duration) as total_time,
            SUM(pages) as total_pages
        FROM page_stat 
        GROUP BY date 
        ORDER BY date DESC 
        LIMIT 30
        """)
        
        daily_stats = cursor.fetchall()
        
        print("\n📊 Recent Reading Activity:")
        print("Date       | Time    | Pages")
        print("-" * 30)
        for date, time_sec, pages in daily_stats:
            if time_sec:
                hours = time_sec // 3600
                minutes = (time_sec % 3600) // 60
                print(f"{date} | {hours}h {minutes:02d}m | {pages or 0}")
        
    except sqlite3.Error as e:
        print(f"Error reading statistics: {e}")
    finally:
        if conn:
            conn.close()

def main():
    parser = argparse.ArgumentParser(description='Extract highlights from KOReader database')
    parser.add_argument('db_path', help='Path to statistics.sqlite3 file')
    parser.add_argument('--format', choices=['text', 'json'], default='text', 
                       help='Output format (default: text)')
    parser.add_argument('--book', help='Filter by book title or author')
    parser.add_argument('--stats', action='store_true', help='Show reading statistics')
    
    args = parser.parse_args()
    
    print("📖 KOReader Highlights Extractor")
    print("=" * 40)
    
    # Extract highlights
    results = extract_highlights(args.db_path, args.format, args.book)
    
    # Show reading stats if requested
    if args.stats:
        extract_reading_stats(args.db_path)
    
    # Important note about actual highlight content
    print("\n" + "=" * 60)
    print("⚠️  IMPORTANT NOTE:")
    print("The statistics database only contains highlight COUNTS.")
    print("Actual highlight CONTENT is stored in .sdr metadata files.")
    print("To extract full highlights, we need to parse the .sdr files")
    print("next to your EPUB files in the books directory.")
    print("=" * 60)

if __name__ == '__main__':
    main()