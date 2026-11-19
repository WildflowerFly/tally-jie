// Neutral details/budget surfaces; only expense and over-budget states retain an accent.
// Scoped here so other pages and shared destructive actions keep their existing theme.
export class DetailsPalette {
  static readonly income: string = '#707070';
  static readonly incomeOnDark: string = '#B8B8B8';
  static readonly expense: string = '#EC5F36';
  static readonly availableBudget: string = '#707070';
  static readonly background: string = '#F5F5F5';
  static readonly surfaceMuted: string = '#F3F3F3';
  static readonly text: string = '#303030';
  static readonly secondary: string = '#777777';
  static readonly muted: string = '#999999';
  static readonly faint: string = '#ADADAD';
  static readonly strongBackground: string = '#373737';
  static readonly ringTrack: string = '#F0F0F0';
  static readonly handle: string = '#DDDDDD';
  static readonly overBudgetBackground: string = '#FFF4E8';
}
