// Display formatting only: never write padded decimals back into the keypad draft.
export function displayAmount(amount: string): string {
  const parts = (amount || '0').split('.');
  return `${parts[0] || '0'}.${(parts[1] || '').padEnd(2, '0').slice(0, 2)}`;
}
