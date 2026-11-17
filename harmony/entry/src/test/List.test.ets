import localUnitTest from './LocalUnit.test';
import ledgerDomainTest from './LedgerDomain.test';
import legacyMigrationTest from './LegacyMigration.test';
import accountTest from './Account.test';
import categoryTest from './Category.test';
import transactionTest from './Transaction.test';
import queryTest from './Query.test';
import statisticsTest from './Statistics.test';
import budgetTest from './Budget.test';
import transferTest from './Transfer.test';
import exchangeTest from './Exchange.test';
import cardsTest from './Cards.test';
import chartsTest from './Charts.test';
import entryQueryTest from './EntryQuery.test';
import ledgerIntegrationTest from './LedgerIntegration.test';

export default function testsuite() {
  localUnitTest();
  ledgerDomainTest();
  legacyMigrationTest();
  accountTest();
  categoryTest();
  transactionTest();
  queryTest();
  statisticsTest();
  budgetTest();
  transferTest();
  exchangeTest();
  ledgerIntegrationTest();
  entryQueryTest();
  chartsTest();
  cardsTest();
}