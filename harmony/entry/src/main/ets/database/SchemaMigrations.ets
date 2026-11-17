import { relationalStore } from '@kit.ArkData';

interface SearchPayload { name: string; note: string; }
// Schema changes only here. The v2 ledger is separate from the legacy JSON file.
export async function migrateSchema(store: relationalStore.RdbStore): Promise<void> {
  if (store.version > 2) { throw new Error('UNSUPPORTED_DATABASE_VERSION'); }
  await store.executeSql('PRAGMA foreign_keys = ON');
  const check = await store.querySql('PRAGMA foreign_keys');
  try {
    if (!check.goToFirstRow() || check.getLong(0) !== 1) { throw new Error('FOREIGN_KEYS_UNAVAILABLE'); }
  } finally { check.close(); }
  if (store.version === 2) { return; }
  const originalVersion = store.version;
  store.beginTransaction();
  try {
    if (originalVersion === 0) {
    await store.executeSql('CREATE TABLE ledger_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE accounts (id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE categories (id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE attachments (id TEXT PRIMARY KEY, payload TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE entries (id TEXT PRIMARY KEY, account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT, category_id TEXT NOT NULL REFERENCES categories(id) ON DELETE RESTRICT, date TEXT NOT NULL, time TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), type TEXT NOT NULL CHECK(type IN (\'income\',\'expense\')), payload TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE entry_assets (entry_id TEXT NOT NULL REFERENCES entries(id) ON DELETE RESTRICT, asset_id TEXT NOT NULL REFERENCES attachments(id) ON DELETE RESTRICT, PRIMARY KEY(entry_id,asset_id))');
    await store.executeSql('CREATE TABLE transfers (id TEXT PRIMARY KEY, from_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT, to_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT, date TEXT NOT NULL, time TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>0), payload TEXT NOT NULL, CHECK(from_id<>to_id))');
    await store.executeSql('CREATE TABLE budgets (id TEXT PRIMARY KEY, category_id TEXT REFERENCES categories(id) ON DELETE RESTRICT, start_date TEXT NOT NULL, end_date TEXT NOT NULL, payload TEXT NOT NULL)');
    await store.executeSql('CREATE TABLE import_sources (id TEXT PRIMARY KEY, fingerprint TEXT NOT NULL UNIQUE, imported_at TEXT NOT NULL)');
    await store.executeSql('CREATE INDEX entry_order ON entries(date DESC,time DESC,id DESC)');
    await store.executeSql('CREATE INDEX entry_account ON entries(account_id,date DESC,time DESC,id DESC)');
    await store.executeSql('CREATE INDEX entry_category ON entries(category_id,date DESC,time DESC,id DESC)');
    await store.executeSql('CREATE INDEX transfer_from ON transfers(from_id,date DESC,time DESC,id DESC)');
    await store.executeSql('CREATE INDEX transfer_to ON transfers(to_id,date DESC,time DESC,id DESC)');
    }
    // v2: searchable fields are first-class columns, payload remains the lossless domain envelope.
    await store.executeSql("ALTER TABLE accounts ADD COLUMN name TEXT NOT NULL DEFAULT ''");
    await store.executeSql("ALTER TABLE categories ADD COLUMN name TEXT NOT NULL DEFAULT ''");
    await store.executeSql("ALTER TABLE entries ADD COLUMN note TEXT NOT NULL DEFAULT ''");
    for (const table of ['accounts', 'categories', 'entries']) {
      const rows = await store.querySql(`SELECT id,payload FROM ${table}`);
      const ids: string[] = []; const values: string[] = [];
      try {
        while (rows.goToNextRow()) {
          const payload = JSON.parse(rows.getString(1)) as SearchPayload;
          const value = table === 'entries' ? payload.note : payload.name;
          if (typeof value !== 'string') { throw new Error('INVALID_SEARCH_PAYLOAD'); }
          ids.push(rows.getString(0)); values.push(value);
        }
      } finally { rows.close(); }
      for (let i = 0; i < ids.length; i++) {
        await store.executeSql(`UPDATE ${table} SET ${table === 'entries' ? 'note' : 'name'}=? WHERE id=?`, [values[i], ids[i]]);
      }
    }
    await store.executeSql('CREATE INDEX entry_type_order ON entries(type,date DESC,time DESC,id DESC)');
    await store.executeSql('CREATE INDEX entry_account_type_order ON entries(account_id,type,date DESC,time DESC,id DESC)');
    await store.executeSql('CREATE INDEX entry_category_type_order ON entries(category_id,type,date DESC,time DESC,id DESC)');
    store.version = 2;
    store.commit();
  } catch (error) {
    store.rollBack();
    throw error as Error;
  }
}
