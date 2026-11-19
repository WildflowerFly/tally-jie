import { Category } from '../model/LedgerModels';
import { categoryGlyph } from '../domain/CategoryGlyph';

export function categoryIcon(row: Category): Resource { return categoryImage(row.name, row.iconKey); }

export function categoryImage(name: string, iconKey: string = 'category'): Resource {
  return categoryKeyIcon(categoryGlyph(name, iconKey));
}

export function categoryKeyIcon(key: string): Resource {
  switch (key) {
    case 'food': return $r('app.media.record_food');
    case 'travel': return $r('app.media.record_travel');
    case 'home': return $r('app.media.record_home');
    case 'shopping': return $r('app.media.record_shopping');
    case 'salary': return $r('app.media.record_salary');
    case 'gift': return $r('app.media.record_gift');
    case 'snack': return $r('app.media.record_snack');
    case 'trip': return $r('app.media.record_trip');
    case 'water': return $r('app.media.record_water');
    case 'daily': return $r('app.media.record_daily');
    case 'phone': return $r('app.media.record_phone');
    case 'entertainment': return $r('app.media.record_entertainment');
    case 'study': return $r('app.media.record_study');
    case 'health': return $r('app.media.record_health');
    case 'pet': return $r('app.media.record_pet');
    case 'clothing': return $r('app.media.record_clothing');
    case 'beauty': return $r('app.media.record_beauty');
    case 'sport': return $r('app.media.record_sport');
    case 'digital': return $r('app.media.record_digital');
    case 'social': return $r('app.media.record_social');
    case 'bonus': return $r('app.media.record_bonus');
    case 'parttime': return $r('app.media.record_parttime');
    case 'cashgift': return $r('app.media.record_cashgift');
    case 'investment': return $r('app.media.record_investment');
    case 'interest': return $r('app.media.record_interest');
    case 'dividend': return $r('app.media.record_dividend');
    case 'reimburse': return $r('app.media.record_reimburse');
    case 'refund': return $r('app.media.record_refund');
    case 'receive': return $r('app.media.record_receive');
    default: return $r('app.media.record_category');
  }
}
