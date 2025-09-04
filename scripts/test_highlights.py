#!/usr/bin/env python3
"""
Simple KOReader Highlight Tester
Quick test to extract highlights from .sdr files
"""

import re
from pathlib import Path

def test_extract_highlights(sdr_path):
    """Test highlight extraction from a single .sdr file."""
    
    metadata_file = Path(sdr_path) / 'metadata.epub.lua'
    if not metadata_file.exists():
        print(f"No metadata file: {metadata_file}")
        return
    
    with open(metadata_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print(f"\n=== Testing {sdr_path} ===")
    
    # Look for annotations section
    if '["annotations"]' in content:
        print("✅ Found annotations section")
        
        # Simple approach: find all text entries
        text_matches = re.findall(r'\["text"\]\s*=\s*"([^"]*)"', content)
        
        print(f"Found {len(text_matches)} highlights:")
        for i, text in enumerate(text_matches[:3], 1):
            print(f"  {i}: {text[:100]}...")
        
        if len(text_matches) > 3:
            print(f"  ... and {len(text_matches) - 3} more")
    else:
        print("❌ No annotations section found")
        # Show what sections exist
        sections = re.findall(r'\["([^"]+)"\]\s*=', content)
        print(f"Available sections: {', '.join(sections)}")

# Test a few key books
test_books = [
    'data/books/Deep Work.sdr',
    'data/books/Building a Second Brain.sdr',
    'data/books/If You Want to Walk on Water, You\'ve Got to Get Out of the Boat.sdr'
]

for book in test_books:
    if Path(book).exists():
        test_extract_highlights(book)
    else:
        print(f"❌ Not found: {book}")