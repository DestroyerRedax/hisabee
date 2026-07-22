# Phase 03 Verification Log — Offline Parsing and Reports

## Overview

This log records the three-pass recheck protocol (Static, Behavioural, Integration/Regression) for the offline SMS/transaction parser and unified local report engine according to PRD Section 16.

---

## Component Verification Matrix

### 1. Offline Transaction Parser (`TransactionMessageParser`, `ParsedCandidate`)
- **Static Pass:** Verified 32,000 character limit, 200 line limit, Bengali digit conversion (`০১২৩৪৫৬৭৮৯` -> `0123456789`), character normalization (CRLF, non-breaking space, dashes).
- **Behavioural Pass (`test/domain/transaction_message_parser_test.dart`):**
  - Regression corpus tested against synthetic SMS formats for bKash, Nagad, Rocket, and Bank transfers.
  - Recognizer precedence order verified: Direction -> Method -> Phone -> Bank Name -> Amount -> Date -> Time.
  - Contextual and trailing currency matcher tested (`৳`, `BDT`, `Tk.`).
  - Candidate `canSave` predicate verified: amount must be positive, direction must exist, method must exist, and `gave` direction requires phone number.
  - Confidence calculation verified (`0.22` base up to `1.0` max); verified confidence score never bypasses invalid `canSave` predicate.
  - Calendar overflow date rejection verified (e.g. invalid `31-02-2026`).
  - No automatic database persistence verified.
- **Result:** PASSED.

---

### 2. Unified Local Report Engine & Repository (`UnifiedReportEngine`, `ReportRepositoryImpl`)
- **Static Pass:** Strict date bound validation (`startDate <= endDate`), SQL index utilization (`local_date`), zero floating-point arithmetic.
- **Behavioural & Integration Pass (`test/domain/unified_report_engine_test.dart`):**
  - Tested date range bounds; verified reversed date range (`startDate > endDate`) returns explicit failure result.
  - Tested multi-domain SQL aggregation across Personal, Business, and active profile Transactions.
  - Verified **Expenses are explicitly excluded** from the unified report net totals and record counts.
  - Verified report equations:
    - `totalReceived = personalReceived + businessReceived + transactionReceived`
    - `totalPaid = personalPaid + businessSent + transactionGave`
    - `overallNet = totalReceived - totalPaid`
    - `totalRecordCount = personalCount + businessCount + transactionCount`
  - Verified zero sections when no active profile exists.
- **Result:** PASSED.

---

## Acceptance Criteria Checklist

- [x] Bengali digits, CRLF, nonbreaking spaces, hyphen variants, missing fields, invalid dates, ambiguous direction, and unlabelled numbers are covered by deterministic tests.
- [x] The parser chooses the last contextual/trailing currency amount and the first valid phone/date/time as stated in the PRD.
- [x] A confidence score never bypasses invalid `canSave` criteria.
- [x] Reports produce zero sections when no active profile exists and reject reversed date ranges.
