import abilityTest from './Ability.test';
import persistenceTest from './Persistence.test';
import databaseMigrationTest from './DatabaseMigration.test';

export default function testsuite() {
  abilityTest();
  persistenceTest();
  databaseMigrationTest();
}