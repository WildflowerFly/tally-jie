import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { LedgerDatabase } from '../../../main/ets/database/LedgerDatabase';
import { LedgerRepository } from '../../../main/ets/repository/LedgerRepository';
import { emptyLedger } from '../../../main/ets/model/LedgerModels';

export default function persistenceTest() {
  describe('LedgerPersistence', () => {
    it('transactionRollbackRestartAndStaleWrite', 0, async () => {
      const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      const name = `ledger-test-${Date.now()}.db`;
      let store = await LedgerDatabase.open(context, name);
      try {
        let repository = new LedgerRepository(store);
        expect((await repository.load()) === undefined).assertTrue();
        const first = await repository.initialize(emptyLedger(), null);
        expect(first.revision).assertEqual(1);
        // Injection is after row replacement but before revision/commit.
        const failing = new LedgerRepository(store, () => { throw new Error('INJECTED_DISK_FAILURE'); });
        let rejected = false;
        try { await failing.save(first.data, first.revision); } catch (_) { rejected = true; }
        expect(rejected).assertTrue();
        expect((await repository.load())!.revision).assertEqual(1);
        const second = await repository.save(first.data, 1);
        expect(second.revision).assertEqual(2);
        rejected = false;
        try { await repository.save(first.data, 1); } catch (_) { rejected = true; }
        expect(rejected).assertTrue();
        store.close();
        store = await LedgerDatabase.open(context, name); repository = new LedgerRepository(store);
        expect((await repository.load())!.revision).assertEqual(2);
      } finally { store.close(); await relationalStore.deleteRdbStore(context, name); }
    });
    it('foreignKeysRejectDanglingRows', 0, async () => {
      const context = abilityDelegatorRegistry.getAbilityDelegator().getAppContext();
      const name = `ledger-fk-test-${Date.now()}.db`;
      const store = await LedgerDatabase.open(context, name);
      try {
        let rejected = false;
        try { await store.executeSql('INSERT INTO entry_assets VALUES (?,?)', ['missing-entry', 'missing-asset']); }
        catch (_) { rejected = true; }
        expect(rejected).assertTrue();
      } finally { store.close(); await relationalStore.deleteRdbStore(context, name); }
    });
  });
}
