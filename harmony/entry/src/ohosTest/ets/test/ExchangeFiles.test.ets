import { describe, it, expect } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { relationalStore } from '@kit.ArkData';
import { ExchangeFiles, sourceFingerprint } from '../../../main/ets/service/ExchangeFiles';
import { LedgerDatabase } from '../../../main/ets/database/LedgerDatabase';
import { LedgerRepository } from '../../../main/ets/repository/LedgerRepository';
import { emptyLedger } from '../../../main/ets/model/LedgerModels';
export default function exchangeFilesTest() {
  describe('PortableFilesPlatform', () => {
    it('actualFileRecoveryUsesTransactionalSourceReceipt', 0, async () => {
      const delegator = abilityDelegatorRegistry.getAbilityDelegator();
      await delegator.startAbility({ bundleName: 'com.tallyjie.harmony', abilityName: 'EntryAbility' });
      const context = (await delegator.getCurrentTopAbility()).context;
      const name = `exchange-test-${Date.now()}.db`;
      const store = await LedgerDatabase.open(context, name);
      const image = `images/img_platform_${Date.now()}.jpg`;
      // Never interfere with an existing import journal. This test creates synthetic bytes only.
      expect(fs.accessSync(`${context.filesDir}/exchange-journal.json`)).assertFalse();
      const repository = new LedgerRepository(store); const adapter = new ExchangeFiles(context);
      try {
        await repository.initialize(emptyLedger(), null);
        const source = await sourceFingerprint(`synthetic-${image}`);
        await adapter.stage([{ path: image, base64: 'YWJj' }], source);
        expect(fs.accessSync(`${context.filesDir}/${image}`)).assertTrue();
        await new ExchangeFiles(context).recover(repository);
        expect(fs.accessSync(`${context.filesDir}/${image}`)).assertFalse();
        await adapter.stage([{ path: image, base64: 'YWJj' }], source);
        await repository.save(emptyLedger(), 1, source);
        await new ExchangeFiles(context).recover(repository);
        expect(fs.readTextSync(`${context.filesDir}/${image}`)).assertEqual('abc');
        let rejected = false;
        try { await adapter.stage([{ path: image, base64: 'ZGlmZmVyZW50' }], source); } catch (_) { rejected = true; }
        expect(rejected).assertTrue();
        expect(fs.readTextSync(`${context.filesDir}/${image}`)).assertEqual('abc');
      } finally {
        await adapter.recover(repository);
        if (fs.accessSync(`${context.filesDir}/${image}`)) { fs.unlinkSync(`${context.filesDir}/${image}`); }
        store.close(); await relationalStore.deleteRdbStore(context, name);
      }
    });
  });
}
