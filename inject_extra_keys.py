import os
import re

file_path = r'e:\app\satyakabir\aloo_market\aloo_sbji_mandi\lib\core\utils\app_localizations.dart'

def inject_keys(path, new_keys):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    langs = ['en', 'hi', 'pa', 'gu', 'mr', 'bn', 'ta', 'te', 'kn', 'or']
    
    for lang in langs:
        map_name = f'_{lang}'
        pattern = rf'static const Map<String, String> {map_name} = \{{'
        match = re.search(pattern, content)
        if not match: continue
            
        start_pos = match.end()
        end_pos = content.find('};', start_pos)
        if end_pos == -1: continue

        injection = ""
        for key, translations in new_keys.items():
            if f"'{key}':" in content[start_pos:end_pos]: continue
            val = translations.get(lang, translations.get('en', ''))
            val = val.replace("'", "\\'")
            injection += f"\n    '{key}': '{val}',"
            
        content = content[:end_pos] + injection + content[end_pos:]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS")

new_keys = {
    'please_select': {'en': 'Please select', 'hi': 'कृपया चुनें'},
    'packets': {'en': 'Packets', 'hi': 'पैकेट'},
    'no_data': {'en': 'N/A', 'hi': 'उपलब्ध नहीं'},
    'invalid_phone_error': {'en': '10 digit number required', 'hi': '10 अंकों का नंबर आवश्यक है'},
    'capacity_usage': {'en': 'Capacity Usage', 'hi': 'क्षमता का उपयोग'},
    'delete_storage': {'en': 'Delete Storage', 'hi': 'स्टोरेज हटाएं'},
    'confirm_delete_storage': {'en': 'Are you sure you want to delete this storage?', 'hi': 'क्या आप वाकई इस स्टोरेज को हटाना चाहते हैं?'},
}

inject_keys(file_path, new_keys)
