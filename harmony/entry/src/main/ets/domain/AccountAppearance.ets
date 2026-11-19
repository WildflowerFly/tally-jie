import { Account } from '../model/LedgerModels';

interface BankMark { key: string; name: string; english: string; }
const BANK_MARKS: BankMark[] = [
  { key: 'icbc', name: '工商银行', english: 'ICBC' },
  { key: 'abc', name: '农业银行', english: 'Agricultural Bank of China' },
  { key: 'boc', name: '中国银行', english: 'Bank of China' },
  { key: 'ccb', name: '建设银行', english: 'China Construction Bank' },
  { key: 'bocom', name: '交通银行', english: 'Bank of Communications' },
  { key: 'psbc', name: '邮政储蓄银行', english: 'Postal Savings Bank of China' },
  { key: 'cmb', name: '招商银行', english: 'China Merchants Bank' },
  { key: 'citic', name: '中信银行', english: 'China CITIC Bank' },
  { key: 'pab', name: '平安银行', english: 'Ping An Bank' }
];
export const ACCOUNT_ICON_KEYS: string[] = ['wechat', 'alipay', 'unionpay', 'quickpass']
  .concat(BANK_MARKS.map((mark: BankMark) => mark.key));
// Read old ledgers without offering the retired artwork in the picker or mutating their records.
const RETIRED_ICON_KEYS: string[] = ['cash', 'wallet', 'applepay', 'paypal', 'bank', 'card'];
export function isStoredAccountIcon(key: string): boolean {
  return ACCOUNT_ICON_KEYS.indexOf(key) >= 0 || RETIRED_ICON_KEYS.indexOf(key) >= 0;
}
export function accountIconKey(account: Account): string {
  if (account.iconKey && ACCOUNT_ICON_KEYS.indexOf(account.iconKey) >= 0) { return account.iconKey; }
  if (/微信|wechat/i.test(account.name)) { return 'wechat'; }
  if (/支付宝|alipay/i.test(account.name)) { return 'alipay'; }
  if (/云闪付|quick\s*pass/i.test(account.name)) { return 'quickpass'; }
  if (/银联|union\s*pay/i.test(account.name)) { return 'unionpay'; }
  const bank = BANK_MARKS.find((mark: BankMark) => account.name.includes(mark.name) ||
    (mark.key === 'psbc' && account.name.includes('邮储银行')));
  if (bank) { return bank.key; }
  return ''; // No known provider: never assign an unrelated brand.
}
export function accountIconEnglishName(iconKey: string): string {
  const bank = BANK_MARKS.find((mark: BankMark) => mark.key === iconKey);
  if (bank) { return bank.english; }
  switch (iconKey) {
    case 'wechat': return 'WeChat';
    case 'alipay': return 'Alipay';
    case 'unionpay': return 'UnionPay';
    case 'quickpass': return 'QuickPass';
    default: return '';
  }
}
export function accountEnglishName(account: Account): string {
  if (account.englishName?.trim()) { return account.englishName.trim(); }
  const providerName = accountIconEnglishName(accountIconKey(account));
  if (providerName) { return providerName; }
  // Only established names have a default English label. Never guess the
  // transliteration of a personal account or invent its holder's identity.
  const name = account.name.trim();
  const bank = BANK_MARKS.find((mark: BankMark) => name === mark.name || name === '中国' + mark.name ||
    (mark.key === 'psbc' && name === '邮储银行'));
  if (bank) { return bank.english; }
  switch (name) {
    case '微信': case '微信钱包': return 'WeChat';
    case '支付宝': return 'Alipay';
    case '银联': return 'UnionPay';
    case '云闪付': return 'QuickPass';
    case 'Apple Pay': case 'Apple pay': case 'applepay': return 'Apple Pay';
    case 'PayPal': case 'paypal': return 'PayPal';
    case '现金': return 'Cash';
    case '钱包': return 'Wallet';
    case '储蓄卡': return 'Savings';
    case '银行卡': return 'Bank Account';
    case '信用卡': return 'Credit Card';
    default: return account.name;
  }
}
