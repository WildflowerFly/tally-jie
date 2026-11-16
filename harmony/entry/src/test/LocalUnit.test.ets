import { describe, it, expect } from '@ohos/hypium';
import { AppData, categoryTotals, dateKey, emptyData, monthlyTotal, money, toCents, Transaction,
  validDate, validateData } from '../main/ets/model/AppData';

function transaction(id: string, type: string, amount: number, date: string, category: string): Transaction {
  return { id: id, type: type, amount: amount, category: category, account: '微信', note: '', date: date, time: '12:00', images: [] };
}

function rejectsAmount(value: string): boolean {
  try { toCents(value); return false; } catch { return true; }
}

export default function localUnitTest(): void {
  describe('TallyJieDomain', () => {
    it('moneyUsesIntegerCents', 0, () => {
      expect(toCents('0.10') + toCents('0.20')).assertEqual(30);
      expect(toCents('12.3')).assertEqual(1230);
      expect(money(1230)).assertEqual('12.30');
      expect(money(-30)).assertEqual('-0.30');
      expect(toCents('999999999.99')).assertEqual(99999999999);
    });
    it('rejectsInvalidAmounts', 0, () => {
      ['0', '-1', '1.001', '1e3', 'NaN', '', '01', '1000000000', '0.00'].forEach((value: string) => {
        expect(rejectsAmount(value)).assertTrue();
      });
    });
    it('validatesCalendarDates', 0, () => {
      expect(validDate('2024-02-29')).assertTrue();
      expect(validDate('2025-02-29')).assertFalse();
      expect(validDate('2026-04-31')).assertFalse();
      expect(validDate('2026-13-01')).assertFalse();
      expect(validDate('2026-1-01')).assertFalse();
      expect(dateKey(new Date(2026, 0, 2))).assertEqual('2026-01-02');
    });
    it('monthlyTotalsRespectTypeAndMonth', 0, () => {
      const data = emptyData();
      data.transactions = [transaction('1', 'expense', 10, '2026-11-01', '餐饮'),
        transaction('2', 'expense', 20, '2026-11-30', '餐饮'),
        transaction('3', 'income', 100, '2026-11-01', '工资'),
        transaction('4', 'expense', 50, '2026-12-01', '购物')];
      expect(monthlyTotal(data, '2026-11', 'expense')).assertEqual(30);
      expect(monthlyTotal(data, '2026-11', 'income')).assertEqual(100);
      expect(monthlyTotal(data, '2026-10', 'expense')).assertEqual(0);
      validateData(data);
    });
    it('categoryTotalsSortByAmount', 0, () => {
      const totals = categoryTotals([transaction('1', 'expense', 10, '2026-11-01', '餐饮'),
        transaction('2', 'expense', 30, '2026-11-01', '购物'), transaction('3', 'expense', 10, '2026-11-01', '餐饮')]);
      expect(totals[0].name).assertEqual('购物');
      expect(totals[1].amount).assertEqual(20);
      expect(totals[1].count).assertEqual(2);
      expect(categoryTotals([]).length).assertEqual(0);
    });
    it('rejectsMalformedBackupData', 0, () => {
      const data = emptyData();
      data.transactions = [transaction('1', 'expense', 10.5, '2026-11-01', '餐饮')];
      let rejected = false;
      try { validateData(data); } catch { rejected = true; }
      expect(rejected).assertTrue();
      data.transactions[0].amount = 10;
      data.transactions[0].images = ['../../secret'];
      rejected = false;
      try { validateData(data); } catch { rejected = true; }
      expect(rejected).assertTrue();
    });
    it('rejectsDuplicateIdsAndBudgets', 0, () => {
      const data = emptyData();
      data.transactions = [transaction('1', 'expense', 10, '2026-11-01', '餐饮'), transaction('1', 'income', 20, '2026-11-02', '工资')];
      let rejected = false;
      try { validateData(data); } catch { rejected = true; }
      expect(rejected).assertTrue();
      data.transactions = [];
      data.budgets = [{ month: '2026-11', amount: 100 }, { month: '2026-11', amount: 200 }];
      rejected = false;
      try { validateData(data); } catch { rejected = true; }
      expect(rejected).assertTrue();
    });
    it('roundTripsAllRecords', 0, () => {
      const data = emptyData();
      data.transactions = [transaction('1', 'expense', 1234, '2026-11-01', '餐饮')];
      data.diaries = [{ id: 'd1', date: '2026-11-01', content: '今天也很好', mood: '😊 开心', weather: '☀️ 晴', location: '家', images: ['img_test_1.jpg'] }];
      data.budgets = [{ month: '2026-11', amount: 300000 }];
      const restored = JSON.parse(JSON.stringify(data)) as AppData;
      validateData(restored);
      expect(restored.diaries[0].content).assertEqual('今天也很好');
      expect(restored.transactions[0].amount).assertEqual(1234);
      expect(restored.budgets[0].amount).assertEqual(300000);
    });
  });
}
