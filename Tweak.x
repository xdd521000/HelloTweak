//
//  Tweak.x — 小叮当（微信增强插件）
//  功能：在微信「设置」页顶部加入「小叮当」入口，
//        点进去是设置页，里面有「微信防撤回」开关。
//  说明：不弹窗，所有开关都在微信设置里面操作。
//

#import <UIKit/UIKit.h>

// ============================================================
//  1. 设置存取（用 NSUserDefaults 保存，重启微信依然记住）
// ============================================================

static NSString *const kPrefsSuite = @"com.yourname.hellotweak";
static NSString *const kAntiRevokeKey = @"AntiRevoke";

static BOOL antiRevokeEnabled(void) {
    return [[[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite] boolForKey:kAntiRevokeKey];
}

static void setAntiRevokeEnabled(BOOL enabled) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
    [prefs setBool:enabled forKey:kAntiRevokeKey];
    [prefs synchronize];
}

// ============================================================
//  2. 小叮当设置页（完全自己写的界面，push 到微信导航栈里）
// ============================================================

@interface XDDSettingsViewController : UIViewController
@end

@implementation XDDSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小叮当";
    self.view.backgroundColor = [UIColor whiteColor];

    // 「微信防撤回」开关行
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 120, 200, 30)];
    label.text = @"微信防撤回";
    label.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:label];

    UISwitch *revokeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 122, 50, 30)];
    revokeSwitch.on = antiRevokeEnabled(); // 读取当前开关状态
    [revokeSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:revokeSwitch];

    // 说明文字
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(20, 165, self.view.bounds.size.width - 40, 40)];
    hint.text = @"开启后，好友撤回的消息\n仍会保留在聊天记录里";
    hint.numberOfLines = 2;
    hint.textColor = [UIColor grayColor];
    hint.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:hint];

    // 版本信息
    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(20, 230, self.view.bounds.size.width - 40, 30)];
    ver.text = @"小叮当 v0.0.6 ｜ 适配 iOS 16.2 / Dopamine";
    ver.textColor = [UIColor lightGrayColor];
    ver.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:ver];
}

// 开关变化 → 保存
- (void)switchChanged:(UISwitch *)sender {
    setAntiRevokeEnabled(sender.isOn);
}

@end

// ============================================================
//  3. 在微信「设置」页顶部加入「小叮当」入口
//     原理：微信设置页是 NewSettingViewController，
//     用它的 m_tableViewInfo 往最上面插一个 cell
// ============================================================

@interface NewSettingViewController : UIViewController
@end

@interface MMTableViewInfo : NSObject
- (id)getTableView;
- (void)insertSection:(id)section At:(unsigned long long)index;
@end

@interface MMTableViewSectionInfo : NSObject
+ (id)sectionInfoDefaut;
- (void)addCell:(id)cell;
@end

@interface MMTableViewCellInfo : NSObject
+ (id)normalCellForSel:(SEL)sel target:(id)target title:(NSString *)title accessoryType:(long long)type;
@end

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;

    // 只注入一次，避免重复添加
    static BOOL xddInjected = NO;
    if (xddInjected) return;

    // 安全检测：类/方法不存在就直接跳过（不会导致微信崩溃）
    Class infoCls = NSClassFromString(@"MMTableViewInfo");
    Class sectionCls = NSClassFromString(@"MMTableViewSectionInfo");
    Class cellCls = NSClassFromString(@"MMTableViewCellInfo");
    if (!infoCls || !sectionCls || !cellCls) return;
    if (![sectionCls respondsToSelector:@selector(sectionInfoDefaut)]) return;
    if (![cellCls respondsToSelector:@selector(normalCellForSel:target:title:accessoryType:)]) return;

    id tableViewInfo = [self valueForKey:@"m_tableViewInfo"];
    if (!tableViewInfo || ![tableViewInfo respondsToSelector:@selector(insertSection:At:)]) return;
    if (![tableViewInfo respondsToSelector:@selector(getTableView)]) return;

    id sectionInfo = [sectionCls sectionInfoDefaut];
    if (!sectionInfo || ![sectionInfo respondsToSelector:@selector(addCell:)]) return;

    // 建一个「小叮当」cell，点击打开我们自己的设置页
    id cell = [cellCls normalCellForSel:@selector(xddOpenSettings) target:self title:@"小叮当" accessoryType:1];
    if (!cell) return;

    [sectionInfo addCell:cell];
    [tableViewInfo insertSection:sectionInfo At:0];

    id tableView = [tableViewInfo getTableView];
    if ([tableView respondsToSelector:@selector(reloadData)]) {
        [tableView reloadData];
    }
    xddInjected = YES;
}

// 新增方法：点击「小叮当」cell 后，跳转到我们的设置页
%new
- (void)xddOpenSettings {
    XDDSettingsViewController *vc = [[XDDSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

%end

// ============================================================
//  4. 防撤回（读取开关：开=拦截撤回，关=正常撤回）
// ============================================================

@interface CMessageMgr : NSObject
- (void)onRevokeMsg:(id)arg;
@end

%hook CMessageMgr

- (void)onRevokeMsg:(id)arg {
    if (antiRevokeEnabled()) {
        // 开关开启 → 不调用 %orig，撤回被拦截，消息保留
    } else {
        %orig; // 开关关闭 → 正常撤回
    }
}

%end
