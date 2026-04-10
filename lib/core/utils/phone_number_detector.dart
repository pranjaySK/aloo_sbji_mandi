/// Phone Number Detection Utility
/// Detects if a message contains phone numbers and provides warnings

class PhoneNumberDetector {
  /// Regular expression patterns to detect phone numbers
  /// Matches various phone number formats including:
  /// - 10 digit numbers (Indian mobile)
  /// - Numbers with country code (+91)
  /// - Numbers with spaces, dashes, or dots
  /// - Numbers written with words (e.g., "nine eight seven...")
  
  static final RegExp _phonePatterns = RegExp(
    r'(?:\+91[\s.-]?)?'  // Optional +91 country code
    r'(?:\(?0?\)?[\s.-]?)?'  // Optional (0) or 0
    r'(?:'
    r'[6-9]\d{9}'  // 10 digit mobile number starting with 6-9
    r'|'
    r'[6-9]\d{2}[\s.-]?\d{3}[\s.-]?\d{4}'  // With separators
    r'|'
    r'[6-9]\d{2}[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{3}'  // Alternative format
    r'|'
    r'[6-9]\d[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}'  // Another format
    r')',
    caseSensitive: false,
  );
  
  /// Pattern for digits written as words
  static final RegExp _wordDigitPattern = RegExp(
    r'\b(?:'
    r'zero|one|two|three|four|five|six|seven|eight|nine|'
    r'ek|do|teen|char|paanch|panch|chhe|cheh|saat|aath|nau|'
    r'nol|शून्य|एक|दो|तीन|चार|पांच|छह|सात|आठ|नौ'
    r')\b',
    caseSensitive: false,
  );
  
  /// Pattern for consecutive digits (5+ digits in any format)
  static final RegExp _consecutiveDigitsPattern = RegExp(
    r'(?:\d[\s.-]*){5,}',
  );
  
  /// Pattern for obfuscated numbers (e.g., "9 8 7 6 5 4 3 2 1 0")
  static final RegExp _obfuscatedPattern = RegExp(
    r'(?:\d\s+){4,}\d',
  );
  
  /// Hindi/Hinglish number words
  static final Map<String, int> _numberWords = {
    'zero': 0, 'nol': 0, 'शून्य': 0,
    'one': 1, 'ek': 1, 'एक': 1,
    'two': 2, 'do': 2, 'दो': 2,
    'three': 3, 'teen': 3, 'तीन': 3,
    'four': 4, 'char': 4, 'चार': 4,
    'five': 5, 'paanch': 5, 'panch': 5, 'पांच': 5,
    'six': 6, 'chhe': 6, 'cheh': 6, 'छह': 6,
    'seven': 7, 'saat': 7, 'सात': 7,
    'eight': 8, 'aath': 8, 'आठ': 8,
    'nine': 9, 'nau': 9, 'नौ': 9,
    'ten': 10, 'das': 10, 'दस': 10,
  };

  /// Check if a message contains a phone number
  static bool containsPhoneNumber(String message) {
    if (message.isEmpty) return false;
    
    final cleanedMessage = message.toLowerCase().trim();
    
    // Check for direct phone number patterns
    if (_phonePatterns.hasMatch(cleanedMessage)) {
      return true;
    }
    
    // Check for consecutive digits (potential phone number)
    if (_consecutiveDigitsPattern.hasMatch(cleanedMessage)) {
      // Extract digits and check if it looks like a phone number
      final digits = cleanedMessage.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.length >= 7 && digits.length <= 15) {
        return true;
      }
    }
    
    // Check for obfuscated numbers (spaces between digits)
    if (_obfuscatedPattern.hasMatch(cleanedMessage)) {
      return true;
    }
    
    // Check for number words (trying to spell out phone number)
    final wordMatches = _wordDigitPattern.allMatches(cleanedMessage);
    if (wordMatches.length >= 5) {
      // If 5 or more number words are found, likely trying to share phone number
      return true;
    }
    
    return false;
  }

  /// Get warning message in Hindi and English
  static Map<String, String> getWarningMessage() {
    return {
      'en': '⚠️ Sharing phone numbers is not allowed!\n\nPlease use our in-app chat to communicate. This keeps your personal information safe and ensures fair business practices.',
      'hi': '⚠️ फ़ोन नंबर साझा करना अनुमत नहीं है!\n\nकृपया संवाद के लिए हमारी ऐप चैट का उपयोग करें। यह आपकी व्यक्तिगत जानकारी को सुरक्षित रखता है और निष्पक्ष व्यापार सुनिश्चित करता है।',
    };
  }
  
  /// Get dialog title
  static Map<String, String> getWarningTitle() {
    return {
      'en': 'Phone Number Detected',
      'hi': 'फ़ोन नंबर का पता चला',
    };
  }

  /// Get the reason explanation
  static Map<String, String> getReasonExplanation() {
    return {
      'en': 'Why this rule?\n\n• Protects your privacy\n• Ensures secure transactions through our platform\n• Prevents spam and fraud\n• Maintains fair marketplace for all users',
      'hi': 'यह नियम क्यों?\n\n• आपकी गोपनीयता की रक्षा करता है\n• हमारे प्लेटफॉर्म के माध्यम से सुरक्षित लेनदेन सुनिश्चित करता है\n• स्पैम और धोखाधड़ी को रोकता है\n• सभी उपयोगकर्ताओं के लिए निष्पक्ष बाज़ार बनाए रखता है',
    };
  }
}
