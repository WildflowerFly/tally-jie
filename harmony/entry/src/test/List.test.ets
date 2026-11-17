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
}