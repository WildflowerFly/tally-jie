import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger, LedgerData } from '../main/ets/model/LedgerModels';
import { accountBalance } from '../main/ets/domain/LedgerRules';
import { upsertAccount, removeAccount } from '../main/ets/service/AccountService';

const NOW: string = '2026-11-17T00:00:00.000Z';
function rejects(work: () => void): boolean { try { work(); return false; } catch (_) { return true; } }
function fixture(): LedgerData {
  let data = upsertAccount(emptyLedger(), 'a', ' 现金 ', 'standard', '100', NOW);
  data = upsertAccount(data, 'b', '银行卡', 'standard', '', NOW);
  data.categories.push({ id: 'in', name: '工资', type: 'income', iconKey: 'category', sortOrder: 0, createdAt: NOW, updatedAt: NOW });
  data.categories.push({ id: 'out', name: '餐饮', type: 'expense', iconKey: 'category', sortOrder: 0, createdAt: NOW, updatedAt: NOW });
  data.entries.push({ id: 'e1', accountId: 'a', categoryId: 'in', type: 'income', amountCents: 5000,
    date: '2026-11-17', time: '12:00', note: '', attachmentIds: [], createdAt: NOW, updatedAt: NOW });
  data.entries.push({ id: 'e2', accountId: 'a', categoryId: 'out', type: 'expense', amountCents: 2000,
    date: '2026-11-17', time: '12:01', note: '', attachmentIds: [], createdAt: NOW, updatedAt: NOW });
  return data;
}
export default function accountTest() {
  describe('AccountService', () => {
    it('accountCrudTrimsNamesAndDerivesBalances', 0, () => {
      const data = fixture();
      expect(data.accounts[0].name).assertEqual('现金');
      expect(accountBalance(data, 'a')).assertEqual(13000);
      const next = upsertAccount(data, 'a', '钱包', 'standard', '200', NOW);
      expect(accountBalance(next, 'a')).assertEqual(23000);
      expect(data.accounts[0].name).assertEqual('现金');
      expect(next.entries[0].accountId).assertEqual('a');
      expect(removeAccount(data, 'b').accounts.length).assertEqual(1);
    });
    it('rejectsInvalidNamesDuplicatesAndNonCreditOverdraft', 0, () => {
      const data = fixture();
      expect(rejects(() => upsertAccount(data, 'c', ' ', 'standard', '', NOW))).assertTrue();
      expect(rejects(() => upsertAccount(data, 'c', '现金', 'standard', '', NOW))).assertTrue();
      expect(rejects(() => upsertAccount(data, 'c', '普通', 'standard', '-1', NOW))).assertTrue();
      const credit = upsertAccount(data, 'c', '信用', 'credit', '-10', NOW);
      expect(accountBalance(credit, 'c')).assertEqual(-1000);
      expect(rejects(() => upsertAccount(credit, 'c', '信用', 'standard', '-10', NOW))).assertTrue();
    });
    it('migrationProtectsReferencesAndRejectsSelfTransfersAtomically', 0, () => {
      const data = fixture();
      expect(rejects(() => removeAccount(data, 'a'))).assertTrue();
      const next = removeAccount(data, 'a', 'b');
      expect(next.accounts.length).assertEqual(1);
      expect(next.entries.every((entry) => entry.accountId === 'b')).assertTrue();
      expect(accountBalance(next, 'b')).assertEqual(3000);
      expect(data.entries[0].accountId).assertEqual('a');
      data.transfers.push({ id: 't', fromAccountId: 'a', toAccountId: 'b', amountCents: 100,
        date: '2026-11-17', time: '13:00', note: '', createdAt: NOW, updatedAt: NOW });
      expect(rejects(() => removeAccount(data, 'a', 'b'))).assertTrue();
      expect(data.accounts.length).assertEqual(2);
    });
    it('lastAccountCanBeDeletedAndRecreatedWithoutChangingCommittedData', 0, () => {
      const data = upsertAccount(emptyLedger(), 'only', '唯一账户', 'standard', '12.34', NOW);
      const empty = removeAccount(data, 'only');
      expect(empty.accounts.length).assertEqual(0);
      expect(data.accounts.length).assertEqual(1);
      const next = upsertAccount(empty, 'new', '新账户', 'credit', '-5', NOW);
      expect(next.accounts.length).assertEqual(1);
      expect(accountBalance(next, 'new')).assertEqual(-500);
    });
    it('repairFlagClearsAndCreatedAtSurvivesEditing', 0, () => {
      const data = fixture(); data.accounts[0].needsInitialBalance = true; data.accounts[0].createdAt = null;
      const next = upsertAccount(data, 'a', '现金', 'standard', '', NOW);
      expect(next.accounts[0].needsInitialBalance).assertFalse();
      expect(next.accounts[0].createdAt === null).assertTrue();
      expect(rejects(() => removeAccount(data, 'a', 'missing'))).assertTrue();
    });
  });
}
