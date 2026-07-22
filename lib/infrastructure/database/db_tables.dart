/// SQL Table and Index definitions for Hisabee application schema version 1.
class DbTables {
  static const String appMetadata = 'app_metadata';
  static const String personalEntries = 'personal_entries';
  static const String businessAccounts = 'business_accounts';
  static const String businessEntries = 'business_entries';
  static const String profiles = 'profiles';
  static const String transactions = 'transactions';
  static const String expenses = 'expenses';
  static const String reminders = 'reminders';
  static const String syncOutbox = 'sync_outbox';
  static const String syncConflicts = 'sync_conflicts';
  static const String transferReceipts = 'transfer_receipts';

  static const List<String> createTableStatements = [
    '''
    CREATE TABLE app_metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    ''',
    '''
    CREATE TABLE personal_entries (
      id TEXT PRIMARY KEY,
      direction TEXT NOT NULL,
      name TEXT NOT NULL,
      normalized_name TEXT NOT NULL,
      phone TEXT,
      normalized_phone TEXT,
      amount_minor INTEGER NOT NULL,
      note TEXT NOT NULL,
      local_date TEXT NOT NULL,
      category TEXT NOT NULL,
      attachment_ref TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
    ''',
    '''
    CREATE TABLE business_accounts (
      id TEXT PRIMARY KEY,
      category TEXT NOT NULL,
      title TEXT NOT NULL,
      number TEXT,
      opening_minor INTEGER NOT NULL,
      closing_minor INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
    ''',
    '''
    CREATE TABLE business_entries (
      id TEXT PRIMARY KEY,
      account_id TEXT NOT NULL,
      direction TEXT NOT NULL,
      name TEXT NOT NULL,
      phone TEXT,
      amount_minor INTEGER NOT NULL,
      note TEXT NOT NULL,
      local_date TEXT NOT NULL,
      category TEXT NOT NULL,
      attachment_ref TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      FOREIGN KEY (account_id) REFERENCES business_accounts(id)
    );
    ''',
    '''
    CREATE TABLE profiles (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color_value TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
    ''',
    '''
    CREATE TABLE transactions (
      id TEXT PRIMARY KEY,
      profile_id TEXT NOT NULL,
      display_party TEXT,
      number TEXT,
      amount_minor INTEGER NOT NULL,
      local_date TEXT NOT NULL,
      local_time TEXT,
      method TEXT NOT NULL,
      direction TEXT NOT NULL,
      raw_source TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER,
      FOREIGN KEY (profile_id) REFERENCES profiles(id)
    );
    ''',
    '''
    CREATE TABLE expenses (
      id TEXT PRIMARY KEY,
      amount_minor INTEGER NOT NULL,
      category TEXT NOT NULL,
      note TEXT NOT NULL,
      local_date TEXT NOT NULL,
      attachment_ref TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
    ''',
    '''
    CREATE TABLE reminders (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      note TEXT NOT NULL,
      scope TEXT NOT NULL,
      due_at INTEGER NOT NULL,
      repeat_rule TEXT NOT NULL,
      is_fired INTEGER NOT NULL,
      is_enabled INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      deleted_at INTEGER
    );
    ''',
    '''
    CREATE TABLE sync_outbox (
      operation_id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      operation TEXT NOT NULL,
      payload TEXT NOT NULL,
      payload_version INTEGER NOT NULL,
      base_version INTEGER,
      idempotency_key TEXT UNIQUE NOT NULL,
      attempt_count INTEGER NOT NULL DEFAULT 0,
      next_retry_at INTEGER,
      created_at INTEGER NOT NULL,
      acknowledged_at INTEGER
    );
    ''',
    '''
    CREATE TABLE sync_conflicts (
      id TEXT PRIMARY KEY,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      local_payload TEXT NOT NULL,
      remote_payload TEXT NOT NULL,
      reason TEXT NOT NULL,
      detected_at INTEGER NOT NULL,
      resolution TEXT,
      resolved_at INTEGER
    );
    ''',
    '''
    CREATE TABLE transfer_receipts (
      id TEXT PRIMARY KEY,
      direction TEXT NOT NULL,
      format TEXT NOT NULL,
      filename TEXT NOT NULL,
      file_hash TEXT NOT NULL,
      schema_version INTEGER NOT NULL,
      accepted_count INTEGER NOT NULL,
      duplicate_count INTEGER NOT NULL,
      rejected_count INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
    ''',
  ];

  static const List<String> createIndexStatements = [
    'CREATE INDEX idx_personal_entries_deleted_date ON personal_entries(deleted_at, local_date);',
    'CREATE INDEX idx_business_entries_account_deleted ON business_entries(account_id, deleted_at);',
    'CREATE INDEX idx_transactions_profile_deleted ON transactions(profile_id, deleted_at);',
    'CREATE INDEX idx_expenses_deleted_date ON expenses(deleted_at, local_date);',
    'CREATE INDEX idx_sync_outbox_ack ON sync_outbox(acknowledged_at);',
    'CREATE UNIQUE INDEX idx_sync_outbox_idempotency ON sync_outbox(idempotency_key);',
  ];
}
