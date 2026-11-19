// One semantic mapping for record chips, recent entries, details and statistics.
// Explicit user-selected icons win; legacy generic categories resolve by name.
export function categoryGlyph(name: string, iconKey: string = 'category'): string {
  if (['food', 'travel', 'home', 'shopping', 'salary', 'gift'].includes(iconKey)) { return iconKey; }
  if (/零食/.test(name)) { return 'snack'; }
  if (/餐|饮|吃/.test(name)) { return 'food'; }
  if (/交通|打车|公交|地铁/.test(name)) { return 'travel'; }
  if (/旅行|旅游|机票/.test(name)) { return 'trip'; }
  if (/住房|房租|房贷/.test(name)) { return 'home'; }
  if (/水电|水费|电费|燃气/.test(name)) { return 'water'; }
  if (/日用|百货/.test(name)) { return 'daily'; }
  if (/通讯|通信|话费|流量/.test(name)) { return 'phone'; }
  if (/娱乐|游戏|电影/.test(name)) { return 'entertainment'; }
  if (/学习|教育|书籍/.test(name)) { return 'study'; }
  if (/医|看病|健康|保健|洗脚|药/.test(name)) { return 'health'; }
  if (/宠物/.test(name)) { return 'pet'; }
  if (/服饰|衣服|鞋/.test(name)) { return 'clothing'; }
  if (/美妆|美容|护肤/.test(name)) { return 'beauty'; }
  if (/运动|健身/.test(name)) { return 'sport'; }
  if (/数码|电子/.test(name)) { return 'digital'; }
  if (/社交|聚会/.test(name)) { return 'social'; }
  if (/工资|薪/.test(name)) { return 'salary'; }
  if (/奖金/.test(name)) { return 'bonus'; }
  if (/兼职/.test(name)) { return 'parttime'; }
  if (/红包|礼金/.test(name)) { return 'cashgift'; }
  if (/理财|投资/.test(name)) { return 'investment'; }
  if (/利息/.test(name)) { return 'interest'; }
  if (/分红|股息/.test(name)) { return 'dividend'; }
  if (/报销/.test(name)) { return 'reimburse'; }
  if (/退款|退货/.test(name)) { return 'refund'; }
  if (/收款/.test(name)) { return 'receive'; }
  if (/礼物|礼品|送礼/.test(name)) { return 'gift'; }
  if (/购物/.test(name)) { return 'shopping'; }
  return 'category';
}
