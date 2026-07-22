import 'package:meta/meta.dart';
import '../../core/money/money.dart';

/// Candidate extracted from transaction message text (PRD Section 7).
@immutable
class ParsedCandidate {
  final int startSourceLine;
  final String rawBlockText;
  final Money? amount;
  final String? direction; // 'received' or 'gave'
  final String? method; // bkash, nagad, rocket, flexiload, bank
  final String? phone;
  final String? bankName;
  final String? localDate; // YYYY-MM-DD
  final String? localTime; // HH:MM
  final List<String> warnings;
  final double confidence;
  final bool canSave;

  const ParsedCandidate({
    required this.startSourceLine,
    required this.rawBlockText,
    this.amount,
    this.direction,
    this.method,
    this.phone,
    this.bankName,
    this.localDate,
    this.localTime,
    required this.warnings,
    required this.confidence,
    required this.canSave,
  });

  Map<String, dynamic> toMap() {
    return {
      'start_source_line': startSourceLine,
      'raw_block_text': rawBlockText,
      'amount_minor': amount?.minorUnits,
      'direction': direction,
      'method': method,
      'phone': phone,
      'bank_name': bankName,
      'local_date': localDate,
      'local_time': localTime,
      'warnings': warnings,
      'confidence': confidence,
      'can_save': canSave,
    };
  }
}

/// Parse result wrapper containing candidates and global warnings.
class MessageParseResult {
  final List<ParsedCandidate> candidates;
  final List<String> globalWarnings;

  const MessageParseResult({
    required this.candidates,
    required this.globalWarnings,
  });
}
