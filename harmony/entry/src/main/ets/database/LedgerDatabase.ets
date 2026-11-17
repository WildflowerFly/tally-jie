import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { migrateSchema } from './SchemaMigrations';

export class LedgerDatabase {
  static async open(context: common.Context, name: string = 'tallyjie-ledger.db'): Promise<relationalStore.RdbStore> {
    const store = await relationalStore.getRdbStore(context, { name: name, securityLevel: relationalStore.SecurityLevel.S1 });
    try { await migrateSchema(store); return store; }
    catch (error) { store.close(); throw error as Error; }
  }
}
