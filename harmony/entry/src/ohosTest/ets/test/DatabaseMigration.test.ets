import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { relationalStore } from '@kit.ArkData';
import { LedgerDatabase } from '../../../main/ets/database/LedgerDatabase';
import { LedgerRepository, MigrationArchive } from '../../../main/ets/repository/LedgerRepository';
import { buildLegacyMigration } from '../../../main/ets/service/LegacyMigration';
import { emptyData } from '../../../main/ets/model/AppData';

export default function databaseMigrationTest() {
  describe('LedgerDatabaseMigration', () => {
    it('migrationMarkerIsAtomicAndInitializationIsIdempotent', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
      const name = `ledger-migration-test-${Date.now()}.db`;
      const store = await LedgerDatabase.open(context, name);
      try {
        const data = buildLegacyMigration(emptyData(), '2026-11-17T00:00:00.000Z').data;
        const archive: MigrationArchive = { sourcePath: 'synthetic.json', sourceSha256: 'test-only',
          diaryCount: 0, attachmentCount: 0, migratedAt: '2026-11-17T00:00:00.000Z' };
        const failing = new LedgerRepository(store, () => { throw new Error('INJECTED_INTERRUPTION'); });
        let rejected = false;
        try { await failing.initialize(data, archive); } catch (_) { rejected = true; }
        expect(rejected).assertTrue();
        const repository = new LedgerRepository(store);
        expect((await repository.load()) === undefined).assertTrue();
        expect((await repository.archive()) === undefined).assertTrue();
        const first = await repository.initialize(data, archive);
        const second = await repository.initialize(data, archive);
        expect(first.revision).assertEqual(second.revision);
        expect(second.data.accounts.length).assertEqual(6);
        expect((await repository.archive()) === JSON.stringify(archive)).assertTrue();
      } finally { store.close(); await relationalStore.deleteRdbStore(context, name); }
    });
  });
}
