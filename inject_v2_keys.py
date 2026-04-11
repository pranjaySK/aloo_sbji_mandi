
import re
import os

def inject_keys(file_path, keys_dict):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    for lang_code, translations in keys_dict.items():
        # Find the map for this language
        # Example: 'en': {
        pattern = f"_{lang_code} = \\{{"
        match = re.search(pattern, content)
        if match:
            start_index = match.end()
            # Find the closing brace of the map
            # This is a bit simplified, assumes no nested maps with same indentation
            # For this file, it's roughly the end of the block
            
            # We'll just append before the closing brace of the map
            # Let's find the closing brace by counting braces or looking for next language code
            
            new_lines = ""
            for key, value in translations.items():
                if f"'{key}':" not in content[match.start():match.start()+100000]: # avoid duplicates in that map
                    new_lines += f"    '{key}': '{value}',\n"
            
            if new_lines:
                content = content[:start_index] + "\n" + new_lines + content[start_index:]
        else:
            print(f"Could not find map for {lang_code}")

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

keys_to_inject = {
    'en': {
        'pricing': 'Pricing',
        'failed_to_assign_manager': 'Failed to assign manager',
        'failed_to_remove_manager': 'Failed to remove manager',
        'failed_to_delete': 'Failed to delete',
        'failed_to_pick_image': 'Failed to pick image',
        'failed_to_capture_image': 'Failed to capture image',
        'location_permission_denied': 'Location permission denied',
        'location_permission_permanently_denied': 'Location permission permanently denied. Enable in Settings.',
        'gps_location_captured': 'GPS location captured!',
        'could_not_get_gps_location': 'Could not get GPS location',
        'location_autofilled': 'Location auto-filled from pincode',
        'invalid_pincode_or_not_found': 'Invalid pincode or location not found',
        'one_storage_limit_msg': 'You can only add 1 cold storage. Delete existing one first.',
        'at_least_one_photo_msg': 'Please add at least one photo of your cold storage',
        'failed_to_save': 'Failed to save',
        'required_label': '(Required)',
        'optional_label': '(Optional)',
    },
    'hi': {
        'pricing': 'मूल्य निर्धारण',
        'failed_to_assign_manager': 'मैनेजर नियुक्त करने में विफल',
        'failed_to_remove_manager': 'मैनेजर को हटाने में विफल',
        'failed_to_delete': 'हटाने में विफल',
        'failed_to_pick_image': 'छवि चुनने में विफल',
        'failed_to_capture_image': 'छवि लेने में विफल',
        'location_permission_denied': 'स्थान अनुमति अस्वीकार कर दी गई',
        'location_permission_permanently_denied': 'स्थान अनुमति स्थायी रूप से अस्वीकार कर दी गई। सेटिंग्स में सक्षम करें।',
        'gps_location_captured': 'जीपीएस स्थान कैप्चर किया गया!',
        'could_not_get_gps_location': 'जीपीएस स्थान प्राप्त नहीं हो सका',
        'location_autofilled': 'पिनकोड से स्थान स्वतः भर गया',
        'invalid_pincode_or_not_found': 'अमान्य पिनकोड या स्थान नहीं मिला',
        'one_storage_limit_msg': 'आप केवल 1 कोल्ड स्टोरेज जोड़ सकते हैं। पहले मौजूदा को हटाएं।',
        'at_least_one_photo_msg': 'कृपया अपने कोल्ड स्टोरेज की कम से कम एक फोटो जोड़ें',
        'failed_to_save': 'सहेजने में विफल',
        'required_label': '(आवश्यक)',
        'optional_label': '(वैकल्पिक)',
    },
    'pa': {
        'pricing': 'ਕੀਮਤ ਨਿਰਧਾਰਨ',
        'failed_to_assign_manager': 'ਮੈਨੇਜਰ ਨਿਯੁਕਤ ਕਰਨ ਵਿੱਚ ਅਸਫਲ',
        'failed_to_remove_manager': 'ਮੈਨੇਜਰ ਨੂੰ ਹਟਾਉਣ ਵਿੱਚ ਅਸਫਲ',
        'failed_to_delete': 'ਹਟਾਉਣ ਵਿੱਚ ਅਸਫਲ',
        'failed_to_pick_image': 'ਤਸਵੀਰ ਚੁਣਨ ਵਿੱਚ ਅਸਫਲ',
        'failed_to_capture_image': 'ਤਸਵੀਰ ਲੈਣ ਵਿੱਚ ਅਸਫਲ',
        'location_permission_denied': 'ਟਿਕਾਣਾ ਇਜਾਜ਼ਤ ਇਨਕਾਰ ਕੀਤੀ ਗਈ',
        'location_permission_permanently_denied': 'ਟਿਕਾਣਾ ਇਜਾਜ਼ਤ ਪੱਕੇ ਤੌਰ ਤੇ ਇਨਕਾਰ ਕੀਤੀ ਗਈ। ਸੈਟਿੰਗਾਂ ਵਿੱਚ ਸਮਰੱਥ ਕਰੋ।',
        'gps_location_captured': 'ਜੀਪੀਐਸ ਟਿਕਾਣਾ ਕੈਪਚਰ ਕੀਤਾ ਗਿਆ!',
        'could_not_get_gps_location': 'ਜੀਪੀਐਸ ਟਿਕਾਣਾ ਪ੍ਰਾਪਤ ਨਹੀਂ ਹੋਇਆ',
        'location_autofilled': 'ਪਿਨਕੋਡ ਤੋਂ ਟਿਕਾਣਾ ਆਪਣੇ ਆਪ ਭਰਿਆ ਗਿਆ',
        'invalid_pincode_or_not_found': 'ਅਵੈਧ ਪਿਨਕੋਡ ਜਾਂ ਟਿਕਾਣਾ ਨਹੀਂ ਮਿਲਿਆ',
        'one_storage_limit_msg': 'ਤੁਸੀਂ ਸਿਰਫ਼ 1 ਕੋਲਡ ਸਟੋਰੇਜ ਜੋੜ ਸਕਦੇ ਹੋ। ਪਹਿਲਾਂ ਮੌਜੂਦਾ ਨੂੰ ਹਟਾਓ।',
        'at_least_one_photo_msg': 'ਕਿਰਪਾ ਕਰਕੇ ਆਪਣੇ ਕੋਲਡ ਸਟੋਰੇਜ ਦੀ ਘੱਟੋ-ਘੱਟ ਇੱਕ ਫੋਟੋ ਜੋੜੋ',
        'failed_to_save': 'ਸੰਭਾਲਣ ਵਿੱਚ ਅਸਫਲ',
        'required_label': '(ਲੋੜੀਂਦਾ)',
        'optional_label': '(ਵਿਕਲਪਿਕ)',
    },
    'gu': {
        'pricing': 'કિંમત નિર્ધારણ',
        'failed_to_assign_manager': 'મેનેજરની નિમણૂક કરવામાં નિષ્ફળ',
        'failed_to_remove_manager': 'મેનેજરને દૂર કરવામાં નિષ્ફળ',
        'failed_to_delete': 'દૂર કરવામાં નિષ્ફળ',
        'failed_to_pick_image': 'છબી પસંદ કરવામાં નિષ્ફળ',
        'failed_to_capture_image': 'છબી લેવામાં નિષ્ફળ',
        'location_permission_denied': 'સ્થાન પરવાનગી નકારી કાઢવામાં આવી',
        'location_permission_permanently_denied': 'સ્થાન પરવાનગી કાયમી ધોરણે નકારી કાઢવામાં આવી. સેટિંગ્સમાં સક્ષમ કરો.',
        'gps_location_captured': 'જીપીએસ સ્થાન કેપ્ચર કરવામાં આવ્યું!',
        'could_not_get_gps_location': 'જીપીએસ સ્થાન મેળવી શકાયું નથી',
        'location_autofilled': 'પિનકોડ પરથી સ્થાન આપમેળે ભરાઈ ગયું',
        'invalid_pincode_or_not_found': 'અમાન્ય પિનકોડ અથવા સ્થાન મળ્યું નથી',
        'one_storage_limit_msg': 'તમે ફક્ત 1 કોલ્ડ સ્ટોરેજ ઉમેરી શકો છો. પહેલા અસ્તિત્વમાં છે તે દૂર કરો.',
        'at_least_one_photo_msg': 'કૃપા કરીને તમારા કોલ્ડ સ્ટોરેજની ઓછામાં ઓછી એક ફોટો ઉમેરો',
        'failed_to_save': 'સાચવવામાં નિષ્ફળ',
        'required_label': '(જરૂરી)',
        'optional_label': '(વૈકલ્પિક)',
    },
    'mr': {
        'pricing': 'किंमत निर्धारण',
        'failed_to_assign_manager': 'व्यवस्थापक नियुक्त करण्यात अपयशी',
        'failed_to_remove_manager': 'व्यवस्थापकाला काढण्यात अपयशी',
        'failed_to_delete': 'हटवण्यात अपयशी',
        'failed_to_pick_image': 'प्रतिमा निवडण्यात अपयशी',
        'failed_to_capture_image': 'प्रतिमा घेण्यात अपयशी',
        'location_permission_denied': 'स्थान परवानगी नाकारली',
        'location_permission_permanently_denied': 'स्थान परवानगी कायमची नाकारली. सेटिंग्ज मध्ये सक्षम करा.',
        'gps_location_captured': 'जीपीएस स्थान कॅप्चर केले!',
        'could_not_get_gps_location': 'जीपीएस स्थान मिळू शकले नाही',
        'location_autofilled': 'पिनकोडवरून स्थान आपोआप भरले गेले',
        'invalid_pincode_or_not_found': 'अवैध पिनकोड किंवा स्थान सापडले नाही',
        'one_storage_limit_msg': 'तुम्ही फक्त 1 कोल्ड स्टोरेज जोडू शकता. आधी असलेले हटवा.',
        'at_least_one_photo_msg': 'कृपया आपल्या कोल्ड स्टोरेजचा किमान एक फोटो जोडा',
        'failed_to_save': 'जतन करण्यात अपयशी',
        'required_label': '(आवश्यक)',
        'optional_label': '(पर्यायी)',
    },
    'bn': {
        'pricing': 'মূল্য নির্ধারণ',
        'failed_to_assign_manager': 'ম্যানেজার নিযুক্ত করতে ব্যর্থ',
        'failed_to_remove_manager': 'ম্যানেজারকে অপসারণ করতে ব্যর্থ',
        'failed_to_delete': 'মুছে ফেলতে ব্যর্থ',
        'failed_to_pick_image': 'ছবি চয়ন করতে ব্যর্থ',
        'failed_to_capture_image': 'ছবি তুলতে ব্যর্থ',
        'location_permission_denied': 'অবস্থানের অনুমতি অস্বীকার করা হয়েছে',
        'location_permission_permanently_denied': 'অবস্থানের অনুমতি স্থায়ীভাবে অস্বীকার করা হয়েছে। সেটিংসে সক্ষম করুন।',
        'gps_location_captured': 'জিপিএস অবস্থান ধারণ করা হয়েছে!',
        'could_not_get_gps_location': 'জিপিএস অবস্থান পাওয়া যায়নি',
        'location_autofilled': 'পিনকোড থেকে অবস্থান স্বয়ংক্রিয়ভাবে পূরণ হয়েছে',
        'invalid_pincode_or_not_found': 'অকার্যকর পিনকোড বা অবস্থান পাওয়া যায়নি',
        'one_storage_limit_msg': 'আপনি কেবল 1 টি কোল্ড স্টোরেজ যোগ করতে পারেন। প্রথমে বিদ্যমানটি মুছুন।',
        'at_least_one_photo_msg': 'দয়া করে আপনার কোল্ড স্টোরেজের অন্তত একটি ফটো যোগ করুন',
        'failed_to_save': 'সংরক্ষণ করতে ব্যর্থ',
        'required_label': '(প্রয়োজনীয়)',
        'optional_label': '(ঐচ্ছিক)',
    },
    'ta': {
        'pricing': 'விலை நிர்ணயம்',
        'failed_to_assign_manager': 'மேலாளரை நியமிப்பதில் தோல்வி',
        'failed_to_remove_manager': 'மேலாளரை நீக்குவதில் தோல்வி',
        'failed_to_delete': 'நீக்குவதில் தோல்வி',
        'failed_to_pick_image': 'படத்தைத் தேர்ந்தெடுப்பதில் தோல்வி',
        'failed_to_capture_image': 'படம் எடுப்பதில் தோல்வி',
        'location_permission_denied': 'இருப்பிட அனுமதி மறுக்கப்பட்டது',
        'location_permission_permanently_denied': 'இருப்பிட அனுமதி நிரந்தரமாக மறுக்கப்பட்டது. அமைப்புகளில் இயக்கவும்.',
        'gps_location_captured': 'ஜிபிஎஸ் இருப்பிடம் பிடிக்கப்பட்டது!',
        'could_not_get_gps_location': 'ஜிபிஎஸ் இருப்பிடத்தைப் பெற முடியவில்லை',
        'location_autofilled': 'பின்கோடிலிருந்து இருப்பிடம் தானாக நிரப்பப்பட்டது',
        'invalid_pincode_or_not_found': 'தவறான பின்கோடு அல்லது இருப்பிடம் காணப்படவில்லை',
        'one_storage_limit_msg': 'நீங்கள் 1 குளிர் சேமிப்பை மட்டுமே சேர்க்க முடியும். முதலில் இருப்பதை நீக்கவும்.',
        'at_least_one_photo_msg': 'உங்கள் குளிர் சேமிப்பின் குறைந்தது ஒரு புகைப்படத்தைச் சேர்க்கவும்',
        'failed_to_save': 'சேமிப்பதில் தோல்வி',
        'required_label': '(தேவை)',
        'optional_label': '(விருப்பமானது)',
    },
    'te': {
        'pricing': 'ధర నిర్ణయం',
        'failed_to_assign_manager': 'మేనేజర్‌ని నియమించడంలో విఫలమైంది',
        'failed_to_remove_manager': 'మేనేజర్‌ని తొలగించడంలో విఫలమైంది',
        'failed_to_delete': 'తొలగించడంలో విఫలమైంది',
        'failed_to_pick_image': 'చిత్రాన్ని ఎంచుకోవడంలో విఫలమైంది',
        'failed_to_capture_image': 'చిత్రాన్ని తీయడంలో విఫలమైంది',
        'location_permission_denied': 'స్థాన అనుమతి నిరాకరించబడింది',
        'location_permission_permanently_denied': 'స్థాన అనుమతి శాశ్వతంగా నిరాకరించబడింది. సెట్టింగ్‌లలో ప్రారంభించండి.',
        'gps_location_captured': 'GPS స్థానం క్యాప్చర్ చేయబడింది!',
        'could_not_get_gps_location': 'GPS స్థానాన్ని పొందలేకపోయాము',
        'location_autofilled': 'పిన్‌కోడ్ నుండి స్థానం స్వయంచాలకంగా పూరించబడింది',
        'invalid_pincode_or_not_found': 'చెల్లని పిన్‌కోడ్ లేదా స్థానం కనుగొనబడలేదు',
        'one_storage_limit_msg': 'మీరు 1 కోల్డ్ స్టోరేజీని మాత్రమే జోడించగలరు. ముందుగా ఉన్నదానిని తొలగించండి.',
        'at_least_one_photo_msg': 'దయచేసి మీ కోల్డ్ స్టోరేజీకి సంబంధించిన కనీసం ఒక ఫోటోను జోడించండి',
        'failed_to_save': 'సేవ్ చేయడంలో విఫలమైంది',
        'required_label': '(అవసరం)',
        'optional_label': '(ఐచ్ఛికం)',
    },
    'kn': {
        'pricing': 'ಬೆಲೆ ನಿಗದಿ',
        'failed_to_assign_manager': 'ವ್ಯವಸ್ಥಾಪಕರನ್ನು ನೇಮಿಸಲು ವಿಫಲವಾಗಿದೆ',
        'failed_to_remove_manager': 'ವ್ಯವಸ್ಥಾಪಕರನ್ನು ತೆಗೆದುಹಾಕಲು ವಿಫಲವಾಗಿದೆ',
        'failed_to_delete': 'ಅಳಿಸಲು ವಿಫಲವಾಗಿದೆ',
        'failed_to_pick_image': 'ಚಿತ್ರವನ್ನು ಆಯ್ಕೆ ಮಾಡಲು ವಿಫಲವಾಗಿದೆ',
        'failed_to_capture_image': 'ಚಿತ್ರವನ್ನು ತೆಗೆದುಕೊಳ್ಳಲು ವಿಫಲವಾಗಿದೆ',
        'location_permission_denied': 'ಸ್ಥಳದ ಅನುಮತಿಯನ್ನು ನಿರಾಕರಿಸಲಾಗಿದೆ',
        'location_permission_permanently_denied': 'ಸ್ಥಳದ ಅನುಮತಿಯನ್ನು ಕಾಯಂ ಆಗಿ ನಿರಾಕರಿಸಲಾಗಿದೆ. ಸೆಟ್ಟಿಂಗ್‌ಗಳಲ್ಲಿ ಸಕ್ರಿಯಗೊಳಿಸಿ.',
        'gps_location_captured': 'ಜಿಪಿಎಸ್ ಸ್ಥಳವನ್ನು ಸೆರೆಹಿಡಿಯಲಾಗಿದೆ!',
        'could_not_get_gps_location': 'ಜಿಪಿಎಸ್ ಸ್ಥಳವನ್ನು ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ',
        'location_autofilled': 'ಪಿನ್‌ಕೋಡ್‌ನಿಂದ ಸ್ಥಳವನ್ನು ಸ್ವಯಂಚಾಲಿತವಾಗಿ ಭರ್ತಿ ಮಾಡಲಾಗಿದೆ',
        'invalid_pincode_or_not_found': 'ಅಮಾನ್ಯ ಪಿನ್‌ಕೋಡ್ ಅಥವಾ ಸ್ಥಳ ಕಂಡುಬಂದಿಲ್ಲ',
        'one_storage_limit_msg': 'ನೀವು ಕೇವಲ 1 ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್ ಅನ್ನು ಮಾತ್ರ ಸೇರಿಸಬಹುದು. ಮೊದಲು ಅಸ್ತಿತ್ವದಲ್ಲಿರುವುದನ್ನು ಅಳಿಸಿ.',
        'at_least_one_photo_msg': 'ದಯವಿಟ್ಟು ನಿಮ್ಮ ಕೋಲ್ಡ್ ಸ್ಟೋರೇಜ್‌ನ ಕನಿಷ್ಠ ಒಂದು ಫೋಟೋವನ್ನು ಸೇರಿಸಿ',
        'failed_to_save': 'ಉಳಿಸಲು ವಿಫಲವಾಗಿದೆ',
        'required_label': '(ಅಗತ್ಯವಿದೆ)',
        'optional_label': '(ಐಚ್ಛಿಕ)',
    },
    'or': {
        'pricing': 'ମୂଲ୍ୟ ନିର୍ଦ୍ଧାରଣ',
        'failed_to_assign_manager': 'ମ୍ୟାନେଜର ନିଯୁକ୍ତ କରିବାରେ ବିଫଳ',
        'failed_to_remove_manager': 'ମ୍ୟାନେଜରଙ୍କୁ ହଟାଇବାରେ ବିଫଳ',
        'failed_to_delete': 'ହଟାଇବାରେ ବିଫଳ',
        'failed_to_pick_image': 'ଛବି ଚୟନ କରିବାରେ ବିଫଳ',
        'failed_to_capture_image': 'ଛବି ନେବାରେ ବିଫଳ',
        'location_permission_denied': 'ସ୍ଥାନ ଅନୁମତି ପ୍ରତ୍ୟାଖ୍ୟାନ କରାଯାଇଛି',
        'location_permission_permanently_denied': 'ସ୍ଥାନ ଅନୁମତି ସ୍ଥାୟୀ ଭାବରେ ପ୍ରତ୍ୟାଖ୍ୟାନ କରାଯାଇଛି। ସେଟିଙ୍ଗସରେ ସକ୍ଷମ କରନ୍ତୁ।',
        'gps_location_captured': 'ଜିପିଏସ୍ ସ୍ଥାନ କ୍ୟାପଚର ହୋଇଛି!',
        'could_not_get_gps_location': 'ଜିପିଏସ୍ ସ୍ଥାନ ମିଳିପାରିଲା ନାହିଁ',
        'location_autofilled': 'ପିନକୋଡରୁ ସ୍ଥାନ ସ୍ୱତଃ ପୂରଣ ହୋଇଛି',
        'invalid_pincode_or_not_found': 'ଅବୈଧ ପିନକୋଡ୍ କିମ୍ବା ସ୍ଥାନ ମିଳିଲାନାହିଁ',
        'one_storage_limit_msg': 'ଆପଣ କେବଳ 1 ଟି କୋଲ୍ଡ ଷ୍ଟୋରେଜ୍ ଯୋଡିପାରିବେ। ପ୍ରଥମେ ବିଦ୍ୟମାନକୁ ହଟାନ୍ତୁ।',
        'at_least_one_photo_msg': 'ଦୟାକରି ଆପଣଙ୍କର କୋଲ୍ଡ ଷ୍ଟୋରେଜ୍ ର ଅତି କମରେ ଗୋଟିଏ ଫଟୋ ଯୋଡନ୍ତୁ',
        'failed_to_save': 'ସଂରକ୍ଷଣ କରିବାରେ ବିଫଳ',
        'required_label': '(ଆବଶ୍ୟକ)',
        'optional_label': '(ଇଚ୍ଛାଧୀନ)',
    }
}

inject_keys(r'e:\app\satyakabir\aloo_market\aloo_sbji_mandi\lib\core\utils\app_localizations.dart', keys_to_inject)
print("Keys injected successfully!")
