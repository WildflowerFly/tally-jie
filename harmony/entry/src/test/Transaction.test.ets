import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { saveEntry, deleteEntry, keypadAmount, EntryInput } from '../main/ets/service/TransactionService';
const NOW: string = '2026-11-17T00:00:00.000Z';
function rejects(work: () => void): boolean { try { work(); return false; } catch (_) { return true; } }
function fixture(): LedgerData {
  const data = emptyLedger();
  data.accounts.push({ id: 'a', name: '现金', type: 'standard', initialBalanceCents: 10000,
    needsInitialBalance: false, createdAt: NOW, updatedAt: NOW });
  data.categories.push({ id: 'c', name: '餐饮', type: 'expense', iconKey: 'food', sortOrder: 0, createdAt: NOW, updatedAt: NOW });
  return data;
}
function input(): EntryInput {
  return { id: 'e', type: 'expense', amount: '20', accountId: 'a', categoryId: 'c', date: '2026-11-01', time: '12:30', note: '午餐' };
}
export default function transactionTest() {
  describe('TransactionService', () => {
    it('keypadLimitsDecimalsAndSupportsBackspace', 0, () => {
      expect(keypadAmount('', '.')).assertEqual('0.');
      expect(keypadAmount('0', '5')).assertEqual('5');
      expect(keypadAmount('12.34', '5')).assertEqual('12.34');
      expect(keypadAmount('12.34', 'back')).assertEqual('12.3');
      expect(keypadAmount('12.3', '.')).assertEqual('12.3');
      expect(keypadAmount('999999999', '9')).assertEqual('999999999');
    });
    it('entryCreateRetryAndEditKeepStableIdentityAndCreation', 0, () => {
      const original = fixture(); const row = input();
      const data = saveEntry(original, row, NOW);
      expect(data.entries.length).assertEqual(1); expect(original.entries.length).assertEqual(0);
      expect(saveEntry(data, row, NOW).entries.length).assertEqual(1);
      data.entries[0].createdAt = null;
      row.amount = '18'; row.date = '2026-10-31';
      const edited = saveEntry(data, row, '2026-11-18T00:00:00.000Z');
      expect(edited.entries[0].createdAt === null).assertTrue();
      expect(edited.entries[0].amountCents).assertEqual(1800);
      expect(edited.entries[0].updatedAt).assertEqual('2026-11-18T00:00:00.000Z');
      expect(deleteEntry(edited, 'e').entries.length).assertEqual(0);
    });
    it('invalidFieldsAndOverdraftNeverMutateSnapshot', 0, () => {
      const data = fixture(); const row = input();
      row.amount = '0'; expect(rejects(() => saveEntry(data, row, NOW))).assertTrue();
      row.amount = '101'; expect(rejects(() => saveEntry(data, row, NOW))).assertTrue();
      row.amount = '1'; row.type = 'income'; expect(rejects(() => saveEntry(data, row, NOW))).assertTrue();
      row.type = 'expense'; row.accountId = ''; expect(rejects(() => saveEntry(data, row, NOW))).assertTrue();
      row.accountId = 'a'; row.date = '2026-02-30'; expect(rejects(() => saveEntry(data, row, NOW))).assertTrue();
      row.date = '2026-11-01'; row.time = '25:00'; expect(rejects(() => saveEntry(data, row, NOW))).assertTrue();
      expect(data.entries.length).assertEqual(0);
    });
  });
}
