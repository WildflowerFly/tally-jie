import exchangeFilesTest from './ExchangeFiles.test';
import abilityTest from './Ability.test';
import navigationTest from './Navigation.test';
import persistenceTest from './Persistence.test';
import databaseMigrationTest from './DatabaseMigration.test';

export default function testsuite() {
  abilityTest();
  navigationTest();
  persistenceTest();
  databaseMigrationTest();
  exchangeFilesTest();
}