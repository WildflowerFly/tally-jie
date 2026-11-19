import { UIContext } from '@kit.ArkUI';

export const ACCOUNT_CARD_FONT: string = 'TallyJieMichroma';
export function registerAccountCardFont(context: UIContext): void {
  context.getFont().registerFont({ familyName: ACCOUNT_CARD_FONT, familySrc: $rawfile('Michroma-Regular.ttf') });
}
