/// In-app legal copy for Terms of Service and Privacy Policy.
/// Replace or extend with your lawyer-reviewed text or host URLs later.
class LegalCopy {
  LegalCopy._();

  static String termsOfService(String localeCode) {
    switch (localeCode) {
      case 'hi':
        return _termsHi;
      default:
        return _termsEn;
    }
  }

  static String privacyPolicy(String localeCode) {
    switch (localeCode) {
      case 'hi':
        return _privacyHi;
      default:
        return _privacyEn;
    }
  }

  static const String _termsEn = '''
Last updated: April 2026

1. Acceptance
By using Aloo Market (“the App”), you agree to these Terms of Service. If you do not agree, please do not use the App.

2. The service
The App connects farmers, traders, cold storage operators, and related service providers for information, listings, messaging, and marketplace-style features. We may change or discontinue features with reasonable notice where practicable.

3. Your account
You are responsible for accurate registration information, safeguarding your login, and all activity under your account. You must be legally able to enter contracts in your jurisdiction.

4. User conduct
You agree not to misuse the App, including fraud, harassment, illegal listings, malware, scraping without permission, or circumventing security. We may suspend or terminate accounts that violate these terms.

5. Listings and transactions
Listings and deals are primarily between users. Aloo Market facilitates connections and tools; it is not a party to your contracts unless explicitly stated. You are responsible for compliance with applicable laws (taxes, licenses, quality standards, etc.).

6. Intellectual property
App branding, design, and software are protected. You retain rights to content you submit but grant us a licence to host, display, and operate the service using that content.

7. Disclaimer
The App is provided “as is” to the extent permitted by law. We do not guarantee uninterrupted service or accuracy of third-party or user-generated content.

8. Limitation of liability
To the maximum extent permitted by law, Aloo Market and its operators are not liable for indirect or consequential losses arising from use of the App.

9. Contact
For questions about these terms, contact support through the Help section in the App.
''';

  static const String _termsHi = '''
अंतिम अपडेट: अप्रैल 2026

1. स्वीकृति
आलू मार्केट (“ऐप”) का उपयोग करके आप इन सेवा शर्तों से सहमत होते हैं। यदि सहमत नहीं हैं, तो कृपया ऐप का उपयोग न करें।

2. सेवा
ऐप किसानों, व्यापारियों, कोल्ड स्टोर संचालकों और संबंधित सेवा प्रदाताओं को जानकारी, लिस्टिंग, संदेश और मार्केटप्लेस जैसी सुविधाओं से जोड़ता है। हम सुविधाएँ बदल या बंद कर सकते हैं।

3. आपका खाता
सही पंजीकरण जानकारी, लॉगिन की सुरक्षा और आपके खाते के तहत गतिविधि की जिम्मेदारी आपकी है।

4. उपयोगकर्ता आचरण
धोखाधड़ी, उत्पीड़न, अवैध लिस्टिंग, मैलवेयर या सुरक्षा भंग जैसे दुरुपयोग की अनुमति नहीं है। उल्लंघन पर खाता निलंबित या समाप्त किया जा सकता है।

5. लिस्टिंग और लेनदेन
अधिकांश लेनदेन उपयोगकर्ताओं के बीच होते हैं। आलू मार्केट जोड़ और उपकरण प्रदान करता है; जब तक स्पष्ट न कहा जाए, आपके अनुबंध का पक्ष नहीं है।

6. बौद्धिक संपदा
ऐप की ब्रांडिंग, डिज़ाइन और सॉफ़्टवेयर सुरक्षित हैं। आपकी सामग्री के अधिकार आपके पास रहते हैं, पर सेवा चलाने हेतु उपयोग की अनुमति देते हैं।

7. अस्वीकरण
जहाँ कानून अनुमति दे, ऐप “जैसा है” प्रदान किया जाता है। निरंतर सेवा या तृतीय-पक्ष सामग्री की सटीकता की गारंटी नहीं।

8. दायित्व की सीमा
कानून द्वारा अनुमत अधिकतम सीमा तक, आलू मार्केट अप्रत्यक्ष हानि के लिए उत्तरदायी नहीं है।

9. संपर्क
प्रश्नों के लिए ऐप में सहायता अनुभाग के माध्यम से संपर्क करें।
''';

  static const String _privacyEn = '''
Last updated: April 2026

1. Who we are
This policy describes how Aloo Market (“we”, “us”) handles information when you use our mobile application and related services.

2. Information we collect
• Account details you provide (e.g. name, phone, role, location where you choose to share it).
• Content you post or send (e.g. listings, messages, images).
• Device and usage data needed to run the App (e.g. app version, diagnostics, approximate region for features).
• With your permission: notifications, camera, photos, or location for specific features you use.

3. How we use information
To create and maintain your account, show relevant listings and features, send service notifications, improve security and reliability, and comply with law.

4. Sharing
We do not sell your personal data. We may share information with service providers who help us operate the App (hosting, analytics, messaging) under strict use limits, or when required by law or to protect rights and safety.

5. Storage and security
We use reasonable technical and organisational measures to protect data. No method of transmission over the internet is 100% secure.

6. Your choices
You may update profile information in the App where supported, adjust notification settings, and contact us to exercise rights available in your region (e.g. access, correction, deletion) where applicable.

7. Children
The App is not intended for children below the minimum age required to consent in your region. We do not knowingly collect their personal data.

8. Changes
We may update this policy and will post the new version in the App with an updated date.

9. Contact
For privacy questions, use the Help / Support options in the App.
''';

  static const String _privacyHi = '''
अंतिम अपडेट: अप्रैल 2026

1. हम कौन हैं
यह नीति बताती है कि आलू मार्केट (“हम”) आपकी जानकारी को हमारे मोबाइल ऐप और संबंधित सेवाओं में कैसे संभालता है।

2. हम क्या एकत्र करते हैं
• आपके द्वारा दिया गया खाता विवरण (नाम, फ़ोन, भूमिका, स्थान जहाँ आप साझा करें)।
• आपकी पोस्ट या संदेश (लिस्टिंग, चैट, चित्र)।
• ऐप चलाने हेतु आवश्यक डिवाइस व उपयोग डेटा।
• आपकी अनुमति से: सूचनाएँ, कैमरा, फ़ोटो या स्थान-आधारित सुविधाएँ।

3. उपयोग
खाता बनाना, प्रासंगिक लिस्टिंग दिखाना, सेवा सूचनाएँ, सुरक्षा व स्थिरता, और कानूनी अनुपालन।

4. साझाकरण
हम आपका व्यक्तिगत डेटा बेचते नहीं। होस्टिंग, विश्लेषण आदि के लिए सीमित सेवा प्रदाताओं के साथ, या कानून/सुरक्षा हेतु साझा कर सकते हैं।

5. सुरक्षा
हम उचित तकनीकी व संगठनात्मक उपाय करते हैं; इंटरनेट पर कोई तरीका पूर्ण सुरक्षित नहीं।

6. आपकी पसंद
प्रोफ़ाइल अपडेट, सूचना सेटिंग, और क्षेत्रानुसार अधिकार (पहुँच, सुधार, हटाना) हेतु संपर्क।

7. बच्चे
ऐप उस उम्र से नीचे के बच्चों के लिए नहीं जो आपके क्षेत्र में सहमति की आयु है।

8. परिवर्तन
हम नीति अपडेट कर सकते हैं; ऐप में नई तिथि के साथ दिखाएँगे।

9. संपर्क
गोपनीयता प्रश्नों के लिए ऐप में सहायता विकल्प उपयोग करें।
''';
}
