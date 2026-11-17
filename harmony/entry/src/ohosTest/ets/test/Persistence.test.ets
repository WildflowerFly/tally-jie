import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { LedgerDatabase } from '../../../main/ets/database/LedgerDatabase';
import { LedgerRepository } from '../../../main/ets/repository/LedgerRepository';
import { defaultFilter } from '../../../main/ets/service/LedgerQueryService';
import { upsertAccount } from '../../../main/ets/service/AccountService';
import { upsertCategory } from '../../../main/ets/service/CategoryService';
import { emptyLedger } from '../../../main/ets/model/LedgerModels';

export default function persistenceTest() {
  describe('LedgerPersistence', () => {
    it('transactionRollbackRestartAndStaleWrite', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
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
    it('databasePagesTenThousandTiesAndIncrementalEditAfterRestart', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
      const name = `ledger-page-test-${Date.now()}.db`;
      let store = await LedgerDatabase.open(context, name);
      try {
        const now = '2026-11-17T00:00:00.000Z';
        let data = upsertAccount(emptyLedger(), 'a', '现金', 'standard', '1000', now);
        data = upsertCategory(data, 'c', '餐饮', 'expense', 'food', 0, now);
        for (let i = 0; i < 10000; i++) {
          data.entries.push({ id: `e${i.toString().padStart(5, '0')}`, type: 'expense', amountCents: 1,
            accountId: 'a', categoryId: 'c', date: '2026-11-17', time: '12:00', note: i === 0 ? '100%_' : '',
            attachmentIds: [], createdAt: now, updatedAt: now });
        }
        let repository = new LedgerRepository(store);
        await repository.initialize(data, null);
        const filter = defaultFilter(); const seen: Set<string> = new Set();
        for (let i = 0; i < 200; i++) {
          const result = await repository.query(filter);
          expect(result.page.expenseCents).assertEqual(10000);
          result.page.rows.forEach((row) => { seen.add(row.id); }); filter.cursor = result.page.next;
        }
        expect(seen.size).assertEqual(10000);
        data.entries[0].note = 'updated';
        await repository.save(data, 1);
        store.close(); store = await LedgerDatabase.open(context, name); repository = new LedgerRepository(store);
        filter.cursor = null; filter.keyword = 'updated';
        expect((await repository.query(filter)).page.count).assertEqual(1);
        expect((await repository.load())!.data.entries.length).assertEqual(10000);
      } finally { store.close(); await relationalStore.deleteRdbStore(context, name); }
    });
    it('sourceReceiptCommitsWithDataAndRollsBackOnFailure', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
      const name = `ledger-source-test-${Date.now()}.db`;
      let store = await LedgerDatabase.open(context, name);
      try {
        let repository = new LedgerRepository(store);
        await repository.initialize(emptyLedger(), null);
        const failing = new LedgerRepository(store, () => { throw new Error('INJECTED_DISK_FAILURE'); });
        let rejected = false;
        try { await failing.save(emptyLedger(), 1, 'source-a'); } catch (_) { rejected = true; }
        expect(rejected).assertTrue(); expect(await repository.hasSource('source-a')).assertFalse();
        expect((await repository.load())!.revision).assertEqual(1);
        await repository.save(emptyLedger(), 1, 'source-a');
        store.close(); store = await LedgerDatabase.open(context, name); repository = new LedgerRepository(store);
        expect(await repository.hasSource('source-a')).assertTrue();
        rejected = false;
        try { await repository.save(emptyLedger(), 2, 'source-a'); } catch (_) { rejected = true; }
        expect(rejected).assertTrue(); expect((await repository.load())!.revision).assertEqual(2);
      } finally { store.close(); await relationalStore.deleteRdbStore(context, name); }
    });
    it('foreignKeysRejectDanglingRows', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
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
