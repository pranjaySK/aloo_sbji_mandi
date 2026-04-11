import os
import re

file_path = r'e:\app\satyakabir\aloo_market\aloo_sbji_mandi\lib\core\utils\app_localizations.dart'

def inject_keys(path, new_keys):
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    langs = ['en', 'hi', 'pa', 'gu', 'mr', 'bn', 'ta', 'te', 'kn', 'or']
    
    for lang in langs:
        map_name = f'_{lang}'
        # Pattern: static const Map<String, String> _en = {
        pattern = rf'static const Map<String, String> {map_name} = \{{'
        match = re.search(pattern, content)
        if not match:
            print(f"Could not find map {map_name}")
            continue
            
        start_pos = match.end()
        # Find the closing brace of this map
        end_pos = content.find('};', start_pos)
        if end_pos == -1:
            print(f"Could not find end of map {map_name}")
            continue

        # Build injection string
        injection = ""
        for key, translations in new_keys.items():
            val = translations.get(lang, translations.get('en', ''))
            val = val.replace("'", "\\'")
            # Check if key already exists in this map to avoid duplicates
            if f"'{key}':" in content[start_pos:end_pos]:
                continue
            injection += f"\n    '{key}': '{val}',"
            
        # Insert at the end of the map (just before };)
        content = content[:end_pos] + injection + content[end_pos:]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("SUCCESS")

new_keys = {
    'edit_storage': {
        'en': 'Edit Storage',
        'hi': 'स्टोरेज संपादित करें',
        'pa': 'ਸਟੋਰੇਜ ਸੰਪਾਦਿਤ ਕਰੋ',
        'gu': 'સ્ટોરેજ સંપાદિત કરો',
        'mr': 'स्टोरेज संपादित करा',
        'bn': 'স্টোরেজ সম্পাদনা করুন',
        'ta': 'சேமிப்பகத்தைத் திருத்து',
        'te': 'స్టోરેజ్‌ని సవరించండి',
        'kn': 'ಸಂಗ್ರಹಣೆಯನ್ನು ಎಡಿಟ್ ಮಾಡಿ',
        'or': 'ଷ୍ଟୋରେଜ୍ ସମ୍ପାଦନ କରନ୍ତୁ'
    },
    'add_new_storage': {'en': 'Add New Storage', 'hi': 'नई स्टोरेज जोड़ें'},
    'storage_photo': {'en': 'Storage Photo', 'hi': 'स्टोरेज फोटो'},
    'basic_info': {'en': 'Basic Information', 'hi': 'बुनियादी जानकारी'},
    'storage_name': {'en': 'Storage Name', 'hi': 'स्टोरेज का नाम'},
    'address_details': {'en': 'Address Details', 'hi': 'पते का विवरण'},
    'contact_info': {'en': 'Contact Information', 'hi': 'संपर्क जानकारी'},
    'email_optional': {'en': 'Email (Optional)', 'hi': 'ईमेल (वैकल्पिक)'},
    'total_capacity_packets': {'en': 'Total Capacity (Packets)', 'hi': 'कुल क्षमता (पैकेट)'},
    'price_per_packet_inr': {'en': 'Price per Packet (₹)', 'hi': 'प्रति पैकेट मूल्य (₹)'},
    'storage_availability': {'en': 'Storage Availability', 'hi': 'स्टोरेज की उपलब्धता'},
    'visible_to_farmers': {'en': 'Visible to farmers', 'hi': 'किसानों को दिखाई दे रहा है'},
    'hidden_from_farmers': {'en': 'Hidden from farmers', 'hi': 'किसानों से छिपा हुआ'},
    'update_storage': {'en': 'Update Storage', 'hi': 'स्टोरेज अपडेट करें'},
    'name_is_required': {'en': 'Name is required', 'hi': 'नाम आवश्यक है'},
    'address_is_required': {'en': 'Address is required', 'hi': 'पता आवश्यक है'},
    'pincode_is_required': {'en': 'Pincode is required', 'hi': 'पिनकोड आवश्यक है'},
    'capacity_is_required': {'en': 'Capacity is required', 'hi': 'क्षमता आवश्यक है'},
    'price_is_required': {'en': 'Price is required', 'hi': 'मूल्य आवश्यक है'},
    'phone_is_required': {'en': 'Phone is required', 'hi': 'फोन आवश्यक है'},
    'invalid_pincode_error': {'en': 'Invalid pincode', 'hi': 'अवैध पिनकोड'},
    'failed_to_pick_image': {'en': 'Failed to pick image', 'hi': 'छवि चुनने में विफल'},
    'failed_to_capture_image': {'en': 'Failed to capture image', 'hi': 'छवि लेने में विफल'},
    'gps_location_captured': {'en': 'GPS location captured!', 'hi': 'जीपीएस स्थान कैप्चर किया गया!'},
    'gps_location_error': {'en': 'Could not get GPS location', 'hi': 'जीपीएस स्थान प्राप्त नहीं हो सका'},
    'pincode_auto_fill_success': {'en': 'Location auto-filled from pincode', 'hi': 'पिनकोड से स्थान स्वतः भरा गया'},
    'invalid_pincode_or_not_found': {'en': 'Invalid pincode or location not found', 'hi': 'अवैध पिनकोड या स्थान नहीं मिला'},
    'photo_mandatory_msg': {'en': 'Please add at least one photo of your cold storage', 'hi': 'कृपया अपने कोल्ड स्टोरेज की कम से कम एक फोटो जोड़ें'},
    'photo_1_mandatory': {'en': 'Photo 1 *', 'hi': 'फोटो 1 *'},
    'photo_2_optional': {'en': 'Photo 2', 'hi': 'फोटो 2'},
    'photo_mandatory_note': {'en': '* First photo is mandatory, second is optional', 'hi': '* पहली फोटो अनिवार्य है, दूसरी वैकल्पिक है'},
    'tap_to_add': {'en': 'Tap to add', 'hi': 'जोड़ने के लिए टैप करें'},
    'select_photo': {'en': 'Select Photo', 'hi': 'फोटो चुनें'},
    'required_label': {'en': '(Required)', 'hi': '(अनिवार्य)'},
    'optional_label': {'en': '(Optional)', 'hi': '(वैकल्पिक)'},
    'capturing_gps': {'en': 'Capturing GPS location...', 'hi': 'जीपीएस स्थान कैप्चर किया जा रहा है...'},
    'choose_from_gallery': {'en': 'Choose from Gallery', 'hi': 'गैलरी से चुनें'},
    'take_a_photo': {'en': 'Take a Photo', 'hi': 'फोटो लें'},
}

inject_keys(file_path, new_keys)
