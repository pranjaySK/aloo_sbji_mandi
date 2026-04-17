import json
import re

with open('lib/core/utils/app_localizations.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# The maps look like: static const Map<String, String> _en = { ... };
# Let's extract each map manually by locating it.

locales = ['en', 'hi', 'pa', 'gu', 'mr', 'bn', 'ta', 'te', 'kn', 'or']

import os
os.makedirs('lib/l10n', exist_ok=True)

# Find where English starts: `static const Map<String, String> _en = {`
placeholder_regex = re.compile(r'\{([a-zA-Z0-9_]+)\}')

for locale in locales:
    start_str = f"static const Map<String, String> _{locale} = {{"
    start_idx = text.find(start_str)
    if start_idx == -1:
        print(f"Could not find locale {locale}")
        continue
    
    start_idx += len(start_str)
    
    # Simple brace counting to find the end of the map
    brace_count = 1
    idx = start_idx
    while brace_count > 0 and idx < len(text):
        if text[idx] == '{':
            brace_count += 1
        elif text[idx] == '}':
            brace_count -= 1
        idx += 1
        
    map_text = "{" + text[start_idx:idx]
    
    # It's a dart map, which is very similar to JSON but has single quotes.
    # To parse it, we'll write a simple tokenizer instead of eval
    
    # Actually since it's just keys and values: 'key': 'value', or 'key': '''value'''
    # We can use a regex to extract keys and values, or since we can execute dart code, 
    # the failure above was just that the dart code had extra extensions!
    pass

