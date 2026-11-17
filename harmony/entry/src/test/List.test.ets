import localUnitTest from './LocalUnit.test';
import ledgerDomainTest from './LedgerDomain.test';
import legacyMigrationTest from './LegacyMigration.test';
import accountTest from './Account.test';

export default function testsuite() {
  localUnitTest();
  ledgerDomainTest();
  legacyMigrationTest();
  accountTest();
}