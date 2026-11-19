import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { accountBalance, validateLedger } from '../main/ets/domain/LedgerRules';
import { exportJson, previewJson } from '../main/ets/service/DataExchangeService';
import { upsertAccount, removeAccount } from '../main/ets/service/AccountService';

// There is no transfer editor/service. Old records remain readable for balances/backups.
export default function legacyTransferCompatibilityTest() {
  describe('LegacyTransferCompatibility', () => {
    it('removingTransferFeatureDoesNotEraseHistoricalBalancesOrBackups', 0, () => {
      const now = '2026-11-18T00:00:00.000Z';
      let data = upsertAccount(emptyLedger(), 'a', '现金', 'standard', '1000', now);
      data = upsertAccount(data, 'b', '储蓄', 'standard', '200', now);
      data.transfers.push({ id: 'legacy-transfer', fromAccountId: 'a', toAccountId: 'b', amountCents: 50000,
        date: '2026-11-17', time: '12:00', note: '旧版记录', createdAt: now, updatedAt: now });
      validateLedger(data);
      const restored = previewJson(emptyLedger(), exportJson(data)).data;
      expect(accountBalance(restored, 'a')).assertEqual(50000);
      expect(accountBalance(restored, 'b')).assertEqual(70000);
      expect(JSON.stringify(restored.transfers)).assertEqual(JSON.stringify(data.transfers));
      const edited = upsertAccount(restored, 'a', '现金账户', 'standard', '1000', now);
      expect(JSON.stringify(edited.transfers)).assertEqual(JSON.stringify(data.transfers));
      let rejected = false;
      try { removeAccount(restored, 'a'); } catch (_) { rejected = true; }
      expect(rejected).assertTrue();
    });
  });
}
