# Phase 02 Verification Log — Accounting Domains and Local Repositories

## Overview

This log records the three-pass recheck protocol (Static, Behavioural, Integration/Regression) for all accounting domain components created in Phase 02 according to PRD Section 16.

---

## File & Feature Verification Matrix

### 1. Business Domain (`BusinessAccount`, `BusinessEntry`, `BusinessRepositoryImpl`)
- **Static Pass:** Validated trimmed string lengths, categories, positive amounts, and integer minor units (`Poisha`). Zero floating-point arithmetic.
- **Behavioural & Integration Pass (`test/infrastructure/accounting_repositories_test.dart`):**
  - Tested **one active cash account constraint**: attempting to save a second active `cash` category account fails predictably.
  - Tested **active account requirement**: saving an entry under an inactive/deleted account fails.
  - Tested **cascade soft-delete**: soft deleting a business account soft-deletes all its active linked entries in the SAME SQLite transaction and enqueues `delete` sync outbox records for account and all entries.
  - Tested **authoritative profit equation (`test/domain/accounting_calculators_test.dart`)**: `profit = closing + sent - (opening + received)` tested with zero, boundary, and large values.
- **Result:** PASSED.

---

### 2. Profiles & Profile Transactions Domain (`Profile`, `TransactionRecord`, `ProfileRepositoryImpl`, `TransactionRepositoryImpl`)
- **Static Pass:** Name length constraints (1–80 chars), `gave` direction mandatory phone number check, valid methods (`bkash`, `nagad`, `rocket`, `bank`, `flexiload`).
- **Behavioural & Integration Pass (`test/infrastructure/accounting_repositories_test.dart`):**
  - Tested **first profile activation**: saving the first profile automatically writes its ID to `app_metadata` (`active_profile_id`).
  - Tested **last active profile protection**: attempting to delete the last active profile fails.
  - Tested **transaction reassignment on deletion**: soft deleting a profile with active transactions reassigns all such transactions to the target active profile in the SAME transaction and enqueues `upsert` sync outbox records.
  - Tested `gave` direction phone validation failure.
- **Result:** PASSED.

---

### 3. Expenses & Monthly Calculation (`Expense`, `ExpenseRepositoryImpl`, `ExpenseCalculations`)
- **Static Pass:** Category validation (1–24 chars), note max 300 chars, positive amount validation.
- **Behavioural & Integration Pass:**
  - Tested half-open calendar interval `[first day of M, first day of M+1)` for monthly expense totals.
  - Tested expense soft-deletion filtering.
- **Result:** PASSED.

---

### 4. Reminders & Schedule Algorithm (`Reminder`, `ReminderRepositoryImpl`, `Reminder.calculateNextDueTimestamp`)
- **Static Pass:** Validated scopes (`general`, `personal`, `business`, `transaction`, `expense`) and repeat rules (`none`, `daily`, `weekly`, `monthly`).
- **Behavioural & Integration Pass (`test/domain/reminder_schedule_test.dart`):**
  - Tested schedule algorithm across 28, 29 (leap year), 30, and 31-day month transitions.
  - Tested Jan 31 -> Feb 28 (non-leap year 2026) and Jan 31 -> Feb 29 (leap year 2028) day clamping.
- **Result:** PASSED.

---

## Acceptance Criteria Checklist

- [x] Deleted records are excluded from every active list and calculation.
- [x] Personal, business, transaction, and expense totals match PRD section 6 exactly at zero, boundary, and large-value cases.
- [x] Business deletion never leaves active linked entries; profile deletion never leaves active transactions linked to a deleted profile.
- [x] Reminder month-end scheduling test covers 28/29/30/31-day transitions.
- [x] Each domain repository has failure-path, rollback, and soft-delete tests.
