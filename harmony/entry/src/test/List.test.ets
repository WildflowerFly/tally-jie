import localUnitTest from './LocalUnit.test';
import ledgerDomainTest from './LedgerDomain.test';

export default function testsuite() {
  localUnitTest();
  ledgerDomainTest();
}