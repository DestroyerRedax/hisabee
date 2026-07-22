import '../../core/money/money.dart';
import 'parsed_candidate.dart';

/// Offline deterministic transaction message parser (PRD Section 7).
class TransactionMessageParser {
  const TransactionMessageParser();

  MessageParseResult parse(String inputText) {
    final globalWarnings = <String>[];

    // PRD Section 7.1: Normalization
    var text = inputText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    text = text.replaceAll('\u00A0', ' '); // Non-breaking spaces -> space
    text = text.replaceAll('–', '-').replaceAll('—', '-'); // En/em dash -> hyphen

    // Convert Bengali digits (০-৯) to ASCII digits (0-9)
    text = _convertBengaliDigits(text);

    // Limit input to first 32,000 characters
    if (text.length > 32000) {
      text = text.substring(0, 32000);
      globalWarnings.add('Input text truncated to 32,000 characters');
    }

    // Split on LF and limit to first 200 lines
    var lines = text.split('\n');
    if (lines.length > 200) {
      lines = lines.sublist(0, 200);
      globalWarnings.add('Input lines truncated to 200 lines');
    }

    // Group contiguous non-blank lines into source blocks
    final blocks = _extractSourceBlocks(lines);
    final candidates = <ParsedCandidate>[];

    for (final block in blocks) {
      final candidate = _parseBlock(block.startLine, block.lines);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    if (blocks.isNotEmpty && candidates.isEmpty) {
      globalWarnings.add('No recognized transaction found in message');
    }

    return MessageParseResult(
      candidates: candidates,
      globalWarnings: globalWarnings,
    );
  }

  String _convertBengaliDigits(String input) {
    const bengaliDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(bengaliDigits[i], i.toString());
    }
    return result;
  }

  List<_SourceBlock> _extractSourceBlocks(List<String> lines) {
    final blocks = <_SourceBlock>[];
    int? currentBlockStart;
    List<String>? currentBlockLines;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        if (currentBlockStart == null) {
          currentBlockStart = i + 1; // 1-based index
          currentBlockLines = [trimmed];
        } else {
          currentBlockLines!.add(trimmed);
        }
      } else {
        if (currentBlockStart != null && currentBlockLines != null) {
          blocks.add(_SourceBlock(currentBlockStart, currentBlockLines));
          currentBlockStart = null;
          currentBlockLines = null;
        }
      }
    }

    if (currentBlockStart != null && currentBlockLines != null) {
      blocks.add(_SourceBlock(currentBlockStart, currentBlockLines));
    }

    return blocks;
  }

  ParsedCandidate? _parseBlock(int startLine, List<String> lines) {
    final rawText = lines.join('\n');
    final lowerText = rawText.toLowerCase();
    final warnings = <String>[];

    // 1. Direction
    final hasReceive = _containsAny(lowerText, [
      'receive', 'receives', 'received', 'credit', 'credited', 'deposit', 'deposited', 'cash-in', 'cash in'
    ]);
    final hasGave = _containsAny(lowerText, [
      'send', 'sent', 'gave', 'debit', 'debited', 'cash-out', 'cash out', 'payment'
    ]);

    String? direction;
    if (hasReceive && !hasGave) {
      direction = 'received';
    } else if (hasGave && !hasReceive) {
      direction = 'gave';
    } else {
      warnings.add('Direction is unclear or missing');
    }

    // 2. Method
    String? method;
    if (lowerText.contains('bkash')) {
      method = 'bkash';
    } else if (lowerText.contains('nagad')) {
      method = 'nagad';
    } else if (lowerText.contains('rocket')) {
      method = 'rocket';
    } else if (lowerText.contains('flexiload')) {
      method = 'flexiload';
    } else {
      final bankMatch = RegExp(r'\b([A-Za-z ]{3,40}\s+Bank)\b', caseSensitive: false).firstMatch(rawText);
      if (bankMatch != null || lowerText.contains('bank')) {
        method = 'bank';
      } else {
        warnings.add('Transaction method is missing or unrecognized');
      }
    }

    // 3. Phone Number
    final phone = _extractPhoneNumber(rawText);
    if (phone == null && direction == 'gave') {
      warnings.add('Missing required phone number for gave transaction');
    }

    // 4. Bank Name Fallback
    final bankName = _extractBankName(rawText);
    if (phone == null && bankName != null && direction == 'received') {
      warnings.add('Using bank name as party fallback');
    }

    // 5. Amount
    final amount = _extractAmount(rawText);
    if (amount == null || !amount.isPositive) {
      warnings.add('Missing or nonpositive amount');
    }

    // 6. Date
    final localDate = _extractDate(rawText);
    if (localDate == null) {
      warnings.add('Missing date; will default to local calendar day at review time');
    }

    // 7. Time
    final localTime = _extractTime(rawText);
    if (localTime == null) {
      warnings.add('Missing time');
    }

    // PRD 7.2: Discard candidate ONLY when amount, direction, phone, and method are ALL absent.
    if (amount == null && direction == null && phone == null && method == null) {
      return null;
    }

    // PRD 7.3: canSave rule
    final canSave = (amount != null && amount.isPositive) &&
        direction != null &&
        method != null &&
        (direction != 'gave' || (phone != null && phone.isNotEmpty));

    // Confidence Calculation
    double confidence = 0.22;
    if (amount != null && amount.isPositive) confidence += 0.28;
    if (direction != null) confidence += 0.16;
    if (phone != null || bankName != null) confidence += 0.12;
    if (method != null) confidence += 0.10;
    if (localDate != null) confidence += 0.07;
    if (localTime != null) confidence += 0.05;
    if (confidence > 1.0) confidence = 1.0;

    return ParsedCandidate(
      startSourceLine: startLine,
      rawBlockText: rawText,
      amount: amount,
      direction: direction,
      method: method,
      phone: phone,
      bankName: bankName,
      localDate: localDate,
      localTime: localTime,
      warnings: warnings,
      confidence: confidence,
      canSave: canSave,
    );
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  String? _extractPhoneNumber(String text) {
    final phoneRegex = RegExp(r'(?<!\d)(?:\+?88)?01[3-9][\d \-]{8,12}(?!\d)');
    final matches = phoneRegex.allMatches(text);

    for (final match in matches) {
      var raw = match.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
      if (raw.startsWith('8801')) {
        raw = raw.substring(2);
      }
      if (RegExp(r'^01[3-9]\d{8}$').hasMatch(raw)) {
        return raw;
      }
    }
    return null;
  }

  String? _extractBankName(String text) {
    final bankRegex = RegExp(r'\b([A-Z][a-zA-Z ]{2,38}\s+Bank)\b', caseSensitive: false);
    final match = bankRegex.firstMatch(text);
    return match?.group(1)?.trim();
  }

  Money? _extractAmount(String text) {
    // 1. Try contextual matches (Tk, BDT, ৳, Amount: etc.)
    final contextualRegex = RegExp(
      r'(?:৳|bdt|tk\.?|amount(?:\s*[:=])?)\s*(-?\d+(?:,\d+)*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final contextualMatches = contextualRegex.allMatches(text);
    if (contextualMatches.isNotEmpty) {
      final lastMatch = contextualMatches.last;
      final rawNum = lastMatch.group(1)!;
      try {
        final money = Money.parse(rawNum);
        if (money.isPositive) return money;
      } catch (_) {}
    }

    // 2. Try trailing number followed by currency marker
    final trailingRegex = RegExp(
      r'(-?\d+(?:,\d+)*(?:\.\d{1,2})?)\s*(?:৳|bdt|tk\.?)',
      caseSensitive: false,
    );
    final trailingMatches = trailingRegex.allMatches(text);
    if (trailingMatches.isNotEmpty) {
      final lastMatch = trailingMatches.last;
      final rawNum = lastMatch.group(1)!;
      try {
        final money = Money.parse(rawNum);
        if (money.isPositive) return money;
      } catch (_) {}
    }

    return null;
  }

  String? _extractDate(String text) {
    // Try ISO-like YYYY-MM-DD or YYYY/MM/DD
    final isoMatch = RegExp(r'\b(20\d{2})[-/](0[1-9]|1[0-2])[-/](0[1-9]|[12]\d|3[01])\b').firstMatch(text);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      if (_isValidDate(year, month, day)) {
        return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }

    // Try Day-first DD-MM-20YY or DD/MM/20YY
    final dayFirstMatch = RegExp(r'\b(0[1-9]|[12]\d|3[01])[-/](0[1-9]|1[0-2])[-/](20\d{2})\b').firstMatch(text);
    if (dayFirstMatch != null) {
      final day = int.parse(dayFirstMatch.group(1)!);
      final month = int.parse(dayFirstMatch.group(2)!);
      final year = int.parse(dayFirstMatch.group(3)!);
      if (_isValidDate(year, month, day)) {
        return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      }
    }

    return null;
  }

  bool _isValidDate(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    final maxDays = DateTime(year, month + 1, 0).day;
    return day >= 1 && day <= maxDays;
  }

  String? _extractTime(String text) {
    final timeRegex = RegExp(
      r'\b([01]?\d|2[0-3]):([0-5]\d)\s*(AM|PM|am|pm)?\b',
    );
    final match = timeRegex.firstMatch(text);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final amPm = match.group(3)?.toUpperCase();

    if (amPm != null) {
      if (amPm == 'AM' && hour == 12) {
        hour = 0;
      } else if (amPm == 'PM' && hour < 12) {
        hour += 12;
      }
    }

    return '${hour.toString().padLeft(2, '0')}:$minute';
  }
}
