import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { saveTransfer, deleteTransfer, TransferInput } from '../main/ets/service/TransferService';
import { accountBalance } from '../main/ets/domain/LedgerRules';
function fixture(): LedgerData {
  const data = emptyLedger(); const now = '2026-11-17T00:00:00.000Z';
  data.accounts.push({ id: 'a', name: 'A', type: 'standard', initialBalanceCents: 100000, needsInitialBalance: false, createdAt: now, updatedAt: now });
  data.accounts.push({ id: 'b', name: 'B', type: 'standard', initialBalanceCents: 20000, needsInitialBalance: false, createdAt: now, updatedAt: now }); return data;
}
function rejects(action: () => void): boolean { try { action(); return false; } catch (_) { return true; } }
export default function transferTest() {
  describe('Transfer', () => {
    it('conservesAssetsStableIdAndDeleteReverses', 0, () => {
      const data = fixture(); const now = '2026-11-17T00:00:00.000Z';
      const input: TransferInput = { id: 't', fromAccountId: 'a', toAccountId: 'b', amount: '500', date: '2026-11-17', time: '12:00', note: '调拨' };
      const next = saveTransfer(data, input, now);
      expect(accountBalance(next, 'a')).assertEqual(50000); expect(accountBalance(next, 'b')).assertEqual(70000);
      expect(accountBalance(next, 'a') + accountBalance(next, 'b')).assertEqual(120000);
      expect(saveTransfer(next, input, now).transfers.length).assertEqual(1); expect(data.transfers.length).assertEqual(0);
      expect(accountBalance(deleteTransfer(next, 't'), 'a')).assertEqual(100000);
      input.amount = '800'; expect(accountBalance(saveTransfer(next, input, now), 'a')).assertEqual(20000);
    });
    it('invalidAndOrdinaryOverdraftRejectedButCreditRepaymentAllowed', 0, () => {
      const data = fixture(); const now = '2026-11-17T00:00:00.000Z';
      const input: TransferInput = { id: 't', fromAccountId: 'a', toAccountId: 'a', amount: '1', date: '2026-11-17', time: '12:00', note: '' };
      expect(rejects(() => { saveTransfer(data, input, now); })).assertTrue();
      input.toAccountId = 'b'; input.amount = '1001'; expect(rejects(() => { saveTransfer(data, input, now); })).assertTrue();
      input.amount = '0'; expect(rejects(() => { saveTransfer(data, input, now); })).assertTrue();
      input.amount = '100'; input.toAccountId = 'x'; expect(rejects(() => { saveTransfer(data, input, now); })).assertTrue();
      data.accounts[1].type = 'credit'; data.accounts[1].initialBalanceCents = -20000; input.toAccountId = 'b';
      const next = saveTransfer(data, input, now); expect(accountBalance(next, 'b')).assertEqual(-10000);
      expect(next.entries.length).assertEqual(0); expect(next.budgets.length).assertEqual(0);
      next.accounts[1].type = 'standard'; next.accounts[1].initialBalanceCents = 0;
      next.transfers.push({ id: 'spent', fromAccountId: 'b', toAccountId: 'a', amountCents: 10000, date: input.date, time: input.time, note: '', createdAt: now, updatedAt: now });
      expect(rejects(() => { deleteTransfer(next, 't'); })).assertTrue();
    });
  });
}
