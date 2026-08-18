//
//  Tweak.x — 小叮当（微信增强插件）
//  功能：微信「设置」页「小叮当」入口
//        1. 微信防撤回开关
//        2. 自定义撤回提示语（拦截撤回时，屏幕顶部弹出你写的话）
//  说明：不弹窗，所有设置都在微信设置里操作。
//

#import <UIKit/UIKit.h>

// ============================================================
//  1. 设置存取（NSUserDefaults 保存，重启微信依然记住）
// ============================================================

static NSString *const kPrefsSuite = @"com.yourname.hellotweak";
static NSString *const kAntiRevokeKey = @"AntiRevoke";
static NSString *const kRevokeNoticeKey = @"RevokeNoticeText";

// 防撤回开关
static BOOL antiRevokeEnabled(void) {
    return [[[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite] boolForKey:kAntiRevokeKey];
}

static void setAntiRevokeEnabled(BOOL enabled) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
    [prefs setBool:enabled forKey:kAntiRevokeKey];
    [prefs synchronize];
}

// 自定义撤回提示语（没设置就用默认话术）
static NSString *revokeNoticeText(void) {
    NSString *text = [[[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite] stringForKey:kRevokeNoticeKey];
    if (text.length == 0) text = @"对方撤回了一条消息（已被小叮当拦截）";
    return text;
}

static void setRevokeNoticeText(NSString *text) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
    [prefs setObject:text forKey:kRevokeNoticeKey];
    [prefs synchronize];
}

// ============================================================
//  2. 顶部提示条（拦截撤回时显示自定义话术）
// ============================================================

static void showRecallToast(NSString *text) {
    // 防止同一个撤回触发多条提示（2 秒内只提示一次）
    static NSDate *lastShown = nil;
    NSDate *now = [NSDate date];
    if (lastShown && [now timeIntervalSinceDate:lastShown] < 2.0) return;
    lastShown = now;

    dispatch_async(dispatch_get_main_queue(), ^{
        // 建一个置顶的小窗口来放提示（不挡点击）
        UIWindow *toastWin = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        toastWin.windowLevel = 2001;
        toastWin.backgroundColor = [UIColor clearColor];
        toastWin.userInteractionEnabled = NO;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    toastWin.windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
        }
        toastWin.hidden = NO;

        // 提示条（圆角黑底白字）
        UILabel *toast = [[UILabel alloc] initWithFrame:CGRectZero];
        toast.text = text;
        toast.textColor = [UIColor whiteColor];
        toast.font = [UIFont systemFontOfSize:13];
        toast.numberOfLines = 0;
        toast.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
        toast.textAlignment = NSTextAlignmentCenter;
        toast.layer.cornerRadius = 10;
        toast.layer.masksToBounds = YES;

        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGSize size = [toast sizeThatFits:CGSizeMake(screenW - 60, CGFLOAT_MAX)];
        toast.frame = CGRectMake((screenW - size.width - 24) / 2, 70, size.width + 24, size.height + 16);
        toast.alpha = 0;
        [toastWin addSubview:toast];

        // 淡入 → 停留 1.8 秒 → 淡出
        [UIView animateWithDuration:0.25 animations:^{
            toast.alpha = 1;
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{
                toast.alpha = 0;
            } completion:^(BOOL finished) {
                toastWin.hidden = YES;
            }];
        }];
    });
}

// ============================================================
//  3. 小叮当设置页（自己写的界面，push 进微信导航栈）
// ============================================================

@interface XDDSettingsViewController : UIViewController
@end

@implementation XDDSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小叮当";
    self.view.backgroundColor = [UIColor whiteColor];

    // 「微信防撤回」开关
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 110, 200, 30)];
    label.text = @"微信防撤回";
    label.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:label];

    UISwitch *revokeSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 112, 50, 30)];
    revokeSwitch.on = antiRevokeEnabled();
    [revokeSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:revokeSwitch];

    // 说明
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(20, 155, self.view.bounds.size.width - 40, 34)];
    hint.text = @"开启后，好友撤回的消息仍会保留";
    hint.textColor = [UIColor grayColor];
    hint.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:hint];

    // 「撤回提示语」输入框
    UILabel *noticeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 205, 260, 26)];
    noticeLabel.text = @"撤回提示语（拦截时显示）";
    noticeLabel.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:noticeLabel];

    UITextField *noticeField = [[UITextField alloc] initWithFrame:CGRectMake(20, 238, self.view.bounds.size.width - 40, 36)];
    noticeField.borderStyle = UITextBorderStyleRoundedRect;
    noticeField.font = [UIFont systemFontOfSize:14];
    noticeField.text = revokeNoticeText();
    noticeField.placeholder = @"对方撤回了一条消息（已被小叮当拦截）";
    [noticeField addTarget:self action:@selector(noticeChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:noticeField];

    // 版本信息
    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(20, 300, self.view.bounds.size.width - 40, 30)];
    ver.text = @"小叮当 v0.0.7 ｜ 适配 iOS 16.2 / Dopamine";
    ver.textColor = [UIColor lightGrayColor];
    ver.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:ver];
}

- (void)switchChanged:(UISwitch *)sender {
    setAntiRevokeEnabled(sender.isOn);
}

- (void)noticeChanged:(UITextField *)sender {
    setRevokeNoticeText(sender.text);
}

@end

// ============================================================
//  4. 在微信「设置」页顶部加入「小叮当」入口
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

    static BOOL xddInjected = NO;
    if (xddInjected) return;

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

%new
- (void)xddOpenSettings {
    XDDSettingsViewController *vc = [[XDDSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

%end

// ============================================================
//  5. 防撤回 + 自定义提示（读取开关：开=拦截+提示，关=正常撤回）
// ============================================================

@interface CMessageMgr : NSObject
- (void)onRevokeMsg:(id)arg;
@end

%hook CMessageMgr

- (void)onRevokeMsg:(id)arg {
    if (antiRevokeEnabled()) {
        // 开关开启 → 拦截撤回（消息保留），并弹出自定义提示语
        showRecallToast(revokeNoticeText());
    } else {
        %orig; // 开关关闭 → 正常撤回
    }
}

%end
