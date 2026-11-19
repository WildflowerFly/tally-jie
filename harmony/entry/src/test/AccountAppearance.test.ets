import { describe, it, expect } from '@ohos/hypium';
import { emptyLedger } from '../main/ets/model/LedgerModels';
import { validateLedger } from '../main/ets/domain/LedgerRules';
import { upsertAccount } from '../main/ets/service/AccountService';
import { ACCOUNT_ICON_KEYS, accountEnglishName, accountIconKey, accountIconEnglishName } from '../main/ets/domain/AccountAppearance';
import { exportJson, previewJson } from '../main/ets/service/DataExchangeService';

const NOW: string = '2026-11-18T00:00:00.000Z';
function rejects(work: () => void): boolean { try { work(); return false; } catch (_) { return true; } }
export default function accountAppearanceTest() {
  describe('AccountAppearance', () => {
    it('legacyAccountsNeedNoMigrationOrInventedHolder', 0, () => {
      const data = upsertAccount(emptyLedger(), 'a', '微信', 'standard', '200', NOW);
      validateLedger(data);
      expect(accountEnglishName(data.accounts[0])).assertEqual('WeChat');
      expect(accountIconKey(data.accounts[0])).assertEqual('wechat');
      expect(data.accounts[0].holder === undefined).assertTrue();
      data.accounts[0].name = '个人备用金';
      expect(accountEnglishName(data.accounts[0])).assertEqual('个人备用金');
    });
    it('cardMetadataIsTrimmedAndSurvivesLegacyEditorsAndJsonRoundTrips', 0, () => {
      const data = upsertAccount(emptyLedger(), 'a', '我的账户', 'standard', '200', NOW,
        { englishName: ' My Savings ', holder: ' 张三 ', iconKey: 'wallet' });
      expect(data.accounts[0].englishName).assertEqual('My Savings');
      expect(data.accounts[0].holder).assertEqual('张三');
      expect(accountIconKey(data.accounts[0])).assertEqual('');
      const edited = upsertAccount(data, 'a', '备用金', 'standard', '210', NOW);
      expect(edited.accounts[0].englishName).assertEqual('My Savings');
      expect(edited.accounts[0].holder).assertEqual('张三');
      expect(edited.accounts[0].iconKey).assertEqual('wallet');
      expect(data.accounts[0].name).assertEqual('我的账户');
      const restored = previewJson(emptyLedger(), exportJson(edited)).data;
      expect(restored.accounts[0].holder).assertEqual('张三');
      expect(restored.accounts[0].iconKey).assertEqual('wallet');
    });
    it('paymentProviderChoicesSurviveSavesLegacyEditsAndBackupRoundTrips', 0, () => {
      let data = emptyLedger();
      ACCOUNT_ICON_KEYS.forEach((key: string) => {
        data = upsertAccount(data, key, `账户-${key}`, 'standard', '200', NOW,
          { englishName: 'Payment Account', holder: '', iconKey: key });
        expect(accountIconKey(data.accounts.find((account) => account.id === key)!)).assertEqual(key);
      });
      const restored = previewJson(emptyLedger(), exportJson(data)).data;
      ACCOUNT_ICON_KEYS.forEach((key: string) => {
        const edited = upsertAccount(restored, key, `账户-${key}`, 'standard', '200', NOW);
        expect(accountIconKey(edited.accounts.find((account) => account.id === key)!)).assertEqual(key);
      });
      expect(ACCOUNT_ICON_KEYS.length).assertEqual(13);
    });
    it('selectedProviderGeneratesAndPersistsItsEnglishNameWithoutRenamingTheAccount', 0, () => {
      const expected: string[] = ['WeChat', 'Alipay', 'UnionPay', 'QuickPass', 'ICBC',
        'Agricultural Bank of China', 'Bank of China', 'China Construction Bank',
        'Bank of Communications', 'Postal Savings Bank of China', 'China Merchants Bank',
        'China CITIC Bank', 'Ping An Bank'];
      let data = upsertAccount(emptyLedger(), 'a', '日常消费账户', 'standard', '200', NOW,
        { englishName: 'Old Label', holder: '张三', iconKey: 'wechat' });
      ACCOUNT_ICON_KEYS.forEach((key: string, index: number) => {
        const generated = accountIconEnglishName(key);
        expect(generated).assertEqual(expected[index]);
        data = upsertAccount(data, 'a', '日常消费账户', 'standard', '200', NOW,
          { englishName: generated, holder: '张三', iconKey: key });
        const restored = previewJson(emptyLedger(), exportJson(data)).data.accounts[0];
        expect(accountEnglishName(restored)).assertEqual(expected[index]);
        expect(restored.name).assertEqual('日常消费账户');
        expect(restored.holder).assertEqual('张三');
        expect(restored.initialBalanceCents).assertEqual(20000);
      });
      const legacy = upsertAccount(emptyLedger(), 'b', '备用账户', 'standard', '', NOW,
        { englishName: '', holder: '', iconKey: 'ccb' });
      expect(accountEnglishName(legacy.accounts[0])).assertEqual('China Construction Bank');
      expect(accountIconEnglishName('')).assertEqual('');
      expect(accountIconEnglishName('bank')).assertEqual('');
    });
    it('retiredMarksRemainReadableButAreNeverDisplayedOrOffered', 0, () => {
      ['cash', 'wallet', 'applepay', 'paypal', 'bank', 'card'].forEach((key: string) => {
        const data = upsertAccount(emptyLedger(), 'a', '备用', 'credit', '-20', NOW);
        data.accounts[0].iconKey = key;
        const account = previewJson(emptyLedger(), exportJson(data)).data.accounts[0];
        expect(account.initialBalanceCents).assertEqual(-2000);
        expect(account.iconKey).assertEqual(key);
        expect(accountIconKey(account)).assertEqual('');
        account.name = '招商银行'; expect(accountIconKey(account)).assertEqual('cmb');
        expect(ACCOUNT_ICON_KEYS.indexOf(key)).assertEqual(-1);
      });
    });
    it('providerDefaultsAreSpecificAndNeverOverrideAnExplicitChoice', 0, () => {
      const names: string[] = ['微信', '支付宝', '银联', '云闪付', 'Apple Pay', 'PayPal', '招商银行', '信用卡'];
      const keys: string[] = ['wechat', 'alipay', 'unionpay', 'quickpass', '', '', 'cmb', ''];
      const english: string[] = ['WeChat', 'Alipay', 'UnionPay', 'QuickPass', 'Apple Pay', 'PayPal',
        'China Merchants Bank', 'Credit Card'];
      names.forEach((name: string, index: number) => {
        const data = upsertAccount(emptyLedger(), 'a', name, index === 7 ? 'credit' : 'standard', '200', NOW);
        expect(accountIconKey(data.accounts[0])).assertEqual(keys[index]);
        expect(accountEnglishName(data.accounts[0])).assertEqual(english[index]);
      });
      const explicit = upsertAccount(emptyLedger(), 'a', '微信', 'standard', '200', NOW,
        { englishName: '', holder: '', iconKey: 'icbc' });
      expect(accountIconKey(explicit.accounts[0])).assertEqual('icbc');
    });
    it('invalidMetadataIsRejectedWithoutMutatingTheLedger', 0, () => {
      const data = upsertAccount(emptyLedger(), 'a', '我的账户', 'standard', '', NOW);
      expect(rejects(() => upsertAccount(data, 'a', '我的账户', 'standard', '', NOW,
        { englishName: '中文', holder: '', iconKey: 'bank' }))).assertTrue();
      expect(rejects(() => upsertAccount(data, 'a', '我的账户', 'standard', '', NOW,
        { englishName: '', holder: 'a'.repeat(41), iconKey: 'bank' }))).assertTrue();
      expect(rejects(() => upsertAccount(data, 'a', '我的账户', 'standard', '', NOW,
        { englishName: '', holder: '', iconKey: 'not-an-icon' }))).assertTrue();
      expect(data.accounts[0].iconKey === undefined).assertTrue();
    });
  });
}
