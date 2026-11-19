import exchangeFilesTest from './ExchangeFiles.test';
import abilityTest from './Ability.test';
import navigationTest from './Navigation.test';
import depositNavigationTest from './DepositNavigation.test';
import persistenceTest from './Persistence.test';
import databaseMigrationTest from './DatabaseMigration.test';

export default function testsuite() {
  abilityTest();
  navigationTest();
  depositNavigationTest();
  persistenceTest();
  databaseMigrationTest();
  exchangeFilesTest();
}