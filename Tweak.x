//
//  Tweak.x — 小叮当（微信增强插件）
//  功能：
//    1. 微信设置页「小叮当」入口（新接口 WCTableViewManager，适配 8.0.70）
//    2. 微信防撤回开关
//    3. 自定义撤回提示语
//    4. 自动抢红包（延迟秒数 / 只抢群聊 / 只抢单聊 / 防重复）
//  说明：不弹窗，所有设置都在微信设置里操作。
//

#import <UIKit/UIKit.h>

// ============================================================
//  1. 设置存取
// ============================================================

static NSString *const kPrefsSuite = @"com.yourname.hellotweak";
static NSString *const kAntiRevokeKey = @"AntiRevoke";
static NSString *const kRevokeNoticeKey = @"RevokeNoticeText";
static NSString *const kRevokeToastKey = @"RevokeToastEnabled";
static NSString *const kAutoRedEnvelopKey = @"AutoRedEnvelop";
static NSString *const kGrabDelayKey = @"GrabDelaySeconds";
static NSString *const kGrabGroupKey = @"GrabGroupChat";
static NSString *const kGrabSingleKey = @"GrabSingleChat";
static NSString *const kGrabbedSendIdsKey = @"GrabbedSendIds";

static NSUserDefaults *xddPrefs(void) {
    return [[NSUserDefaults alloc] initWithSuiteName:kPrefsSuite];
}

static BOOL antiRevokeEnabled(void) {
    return [xddPrefs() boolForKey:kAntiRevokeKey];
}
static void setAntiRevokeEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kAntiRevokeKey]; [p synchronize];
}

static NSString *revokeNoticeText(void) {
    NSString *t = [xddPrefs() stringForKey:kRevokeNoticeKey];
    return (t.length > 0) ? t : @"对方撤回了一条消息（已被小叮当拦截）";
}
static void setRevokeNoticeText(NSString *t) {
    NSUserDefaults *p = xddPrefs(); [p setObject:t forKey:kRevokeNoticeKey]; [p synchronize];
}

static BOOL revokeToastEnabled(void) {
    return [xddPrefs() boolForKey:kRevokeToastKey];
}
static void setRevokeToastEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kRevokeToastKey]; [p synchronize];
}

static BOOL autoRedEnvelopEnabled(void) {
    return [xddPrefs() boolForKey:kAutoRedEnvelopKey];
}
static void setAutoRedEnvelopEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kAutoRedEnvelopKey]; [p synchronize];
}

static NSInteger grabDelaySeconds(void) {
    NSInteger d = [xddPrefs() integerForKey:kGrabDelayKey];
    if (d < 0 || d > 60) d = 1;
    return d;
}
static void setGrabDelaySeconds(NSInteger d) {
    NSUserDefaults *p = xddPrefs(); [p setInteger:d forKey:kGrabDelayKey]; [p synchronize];
}

static BOOL grabGroupChatEnabled(void) {
    return [xddPrefs() boolForKey:kGrabGroupKey];
}
static void setGrabGroupChatEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kGrabGroupKey]; [p synchronize];
}

static BOOL grabSingleChatEnabled(void) {
    return [xddPrefs() boolForKey:kGrabSingleKey];
}
static void setGrabSingleChatEnabled(BOOL v) {
    NSUserDefaults *p = xddPrefs(); [p setBool:v forKey:kGrabSingleKey]; [p synchronize];
}

// 防重复：已经抢过的红包 sendId 集合
static BOOL isSendIdGrabbed(NSString *sendId) {
    if (!sendId) return NO;
    NSArray *list = [xddPrefs() arrayForKey:kGrabbedSendIdsKey];
    return [list containsObject:sendId];
}
static void markSendIdGrabbed(NSString *sendId) {
    if (!sendId) return;
    NSUserDefaults *p = xddPrefs();
    NSMutableArray *list = [[p arrayForKey:kGrabbedSendIdsKey] mutableCopy];
    if (!list) list = [NSMutableArray array];
    if (![list containsObject:sendId]) [list addObject:sendId];
    if (list.count > 500) [list removeObjectsInRange:NSMakeRange(0, list.count - 500)]; // 只留最近500个
    [p setObject:list forKey:kGrabbedSendIdsKey];
    [p synchronize];
}

// ============================================================
//  2. 顶部提示条
// ============================================================

static void showRecallToast(NSString *text) {
    static NSDate *lastShown = nil;
    NSDate *now = [NSDate date];
    if (lastShown && [now timeIntervalSinceDate:lastShown] < 2.0) return;
    lastShown = now;

    dispatch_async(dispatch_get_main_queue(), ^{
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

        [UIView animateWithDuration:0.25 animations:^{ toast.alpha = 1; }
            completion:^(BOOL finished) {
                [UIView animateWithDuration:0.3 delay:1.8 options:0 animations:^{ toast.alpha = 0; }
                    completion:^(BOOL finished) { toastWin.hidden = YES; }];
            }];
    });
}

// ============================================================
//  3. 微信私有类声明
// ============================================================

@interface MMContext : NSObject
+ (id)activeUserContext;
- (id)getService:(Class)arg1;
@end

@interface CMessageWrap : NSObject
@property(retain, nonatomic) id m_oWCPayInfoItem;
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(assign, nonatomic) NSUInteger m_uiMessageType;
@end

@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface WCBizUtil : NSObject
+ (id)dictionaryWithDecodedComponets:(id)arg1 separator:(id)arg2;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
- (id)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OpenRedEnvelopesRequest:(id)params;
- (void)ReceiverQueryRedEnvelopesRequest:(id)arg1;
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
@end

@interface HongBaoRes : NSObject
@property(retain, nonatomic) id retText;
@property(nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) id reqText;
@end

@interface SKBuiltinBuffer_t : NSObject
@property(retain, nonatomic) NSData *buffer;
@end

// ============================================================
//  4. 小叮当设置页
// ============================================================

@interface XDDSettingsViewController : UIViewController
@end

@implementation XDDSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"小叮当";
    self.view.backgroundColor = [UIColor whiteColor];

    // --- 微信防撤回 ---
    UILabel *label1 = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 30)];
    label1.text = @"微信防撤回";
    label1.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:label1];

    UISwitch *sw1 = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 102, 50, 30)];
    sw1.on = antiRevokeEnabled();
    [sw1 addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    sw1.tag = 101;
    [self.view addSubview:sw1];

    // --- 撤回提示（开关）---
    UILabel *label2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 145, 260, 26)];
    label2.text = @"撤回提示";
    label2.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:label2];

    UISwitch *sw2 = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 142, 50, 30)];
    sw2.on = revokeToastEnabled();
    [sw2 addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    sw2.tag = 102;
    [self.view addSubview:sw2];

    // --- 撤回提示语内容 ---
    UILabel *label3 = [[UILabel alloc] initWithFrame:CGRectMake(20, 185, 260, 26)];
    label3.text = @"撤回提示语（拦截时显示）";
    label3.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:label3];

    UITextField *noticeField = [[UITextField alloc] initWithFrame:CGRectMake(20, 215, self.view.bounds.size.width - 40, 34)];
    noticeField.borderStyle = UITextBorderStyleRoundedRect;
    noticeField.font = [UIFont systemFontOfSize:14];
    noticeField.text = revokeNoticeText();
    noticeField.placeholder = @"对方撤回了一条消息（已被小叮当拦截）";
    [noticeField addTarget:self action:@selector(noticeChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:noticeField];

    // --- 自动抢红包 ---
    UILabel *label4 = [[UILabel alloc] initWithFrame:CGRectMake(20, 270, 200, 30)];
    label4.text = @"自动抢红包";
    label4.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:label4];

    UISwitch *sw3 = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 272, 50, 30)];
    sw3.on = autoRedEnvelopEnabled();
    [sw3 addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    sw3.tag = 103;
    [self.view addSubview:sw3];

    // 延迟秒数
    UILabel *label5 = [[UILabel alloc] initWithFrame:CGRectMake(20, 315, 220, 26)];
    label5.text = @"几秒后抢（0-10 秒）";
    label5.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:label5];

    UITextField *delayField = [[UITextField alloc] initWithFrame:CGRectMake(20, 347, 120, 34)];
    delayField.borderStyle = UITextBorderStyleRoundedRect;
    delayField.keyboardType = UIKeyboardTypeNumberPad;
    delayField.font = [UIFont systemFontOfSize:14];
    delayField.text = [NSString stringWithFormat:@"%ld", (long)grabDelaySeconds()];
    delayField.placeholder = @"1";
    [delayField addTarget:self action:@selector(delayChanged:) forControlEvents:UIControlEventEditingDidEnd];
    [self.view addSubview:delayField];

    // 抢群聊 / 抢单聊
    UILabel *label6 = [[UILabel alloc] initWithFrame:CGRectMake(20, 395, 200, 26)];
    label6.text = @"只抢群聊红包";
    label6.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:label6];
    UISwitch *sw5 = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 393, 50, 30)];
    sw5.on = grabGroupChatEnabled();
    [sw5 addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    sw5.tag = 105;
    [self.view addSubview:sw5];

    UILabel *label7 = [[UILabel alloc] initWithFrame:CGRectMake(20, 433, 200, 26)];
    label7.text = @"只抢单聊红包";
    label7.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:label7];
    UISwitch *sw6 = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.bounds.size.width - 70, 431, 50, 30)];
    sw6.on = grabSingleChatEnabled();
    [sw6 addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    sw6.tag = 106;
    [self.view addSubview:sw6];

    UILabel *hint2 = [[UILabel alloc] initWithFrame:CGRectMake(20, 467, self.view.bounds.size.width - 40, 30)];
    hint2.text = @"提示：抢红包有封号风险，请谨慎使用";
    hint2.textColor = [UIColor orangeColor];
    hint2.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:hint2];

    // 版本
    UILabel *ver = [[UILabel alloc] initWithFrame:CGRectMake(20, 505, self.view.bounds.size.width - 40, 30)];
    ver.text = @"小叮当 v0.0.8 ｜ 适配 iOS 16.2 / Dopamine";
    ver.textColor = [UIColor lightGrayColor];
    ver.font = [UIFont systemFontOfSize:12];
    [self.view addSubview:ver];
}

- (void)switchChanged:(UISwitch *)sender {
    switch (sender.tag) {
        case 101: setAntiRevokeEnabled(sender.isOn); break;
        case 102: setRevokeToastEnabled(sender.isOn); break;
        case 103: setAutoRedEnvelopEnabled(sender.isOn); break;
        case 105: setGrabGroupChatEnabled(sender.isOn); break;
        case 106: setGrabSingleChatEnabled(sender.isOn); break;
        default: break;
    }
}

- (void)noticeChanged:(UITextField *)sender {
    setRevokeNoticeText(sender.text);
}

- (void)delayChanged:(UITextField *)sender {
    NSInteger d = [sender.text integerValue];
    if (d < 0) d = 0;
    if (d > 10) d = 10;
    setGrabDelaySeconds(d);
    sender.text = [NSString stringWithFormat:@"%ld", (long)d];
}

@end

// ============================================================
//  5. 设置页入口（新接口 WCTableViewManager，适配 8.0.70）
// ============================================================

@interface NewSettingViewController : UIViewController
@end

@interface WCTableViewManager : NSObject
@end

%hook WCTableViewManager

// 判断表格是不是微信设置页（通过响应链找到 NewSettingViewController）
static BOOL xddIsSettingsTable(UITableView *tableView) {
    if (!tableView) return NO;
    id next = [tableView nextResponder];
    if ([next isKindOfClass:NSClassFromString(@"NewSettingViewController")]) return YES;
    next = [next nextResponder];
    if ([next isKindOfClass:NSClassFromString(@"NewSettingViewController")]) return YES;
    return NO;
}

- (long long)numberOfSectionsInTableView:(UITableView *)tableView {
    long long n = %orig;
    if (xddIsSettingsTable(tableView)) return n + 1; // 设置页多加一组
    return n;
}

- (long long)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (xddIsSettingsTable(tableView) && section == [self numberOfSectionsInTableView:tableView] - 1) {
        return 1; // 一组一行：小叮当入口
    }
    return %orig;
}

- (id)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (xddIsSettingsTable(tableView) && indexPath.section == [self numberOfSectionsInTableView:tableView] - 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"xddCell"];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"xddCell"];
        cell.textLabel.text = @"🔔 小叮当";
        cell.textLabel.textColor = [UIColor colorWithRed:0.10 green:0.48 blue:0.20 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return cell;
    }
    return %orig;
}

- (double)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (xddIsSettingsTable(tableView) && indexPath.section == [self numberOfSectionsInTableView:tableView] - 1) {
        return 50;
    }
    return %orig;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (xddIsSettingsTable(tableView) && indexPath.section == [self numberOfSectionsInTableView:tableView] - 1) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        id vc = [tableView nextResponder];
        if (![vc isKindOfClass:NSClassFromString(@"NewSettingViewController")]) vc = [vc nextResponder];
        UINavigationController *nav = [vc navigationController];
        if (nav) {
            XDDSettingsViewController *page = [[XDDSettingsViewController alloc] init];
            [nav pushViewController:page animated:YES];
        }
        return;
    }
    %orig;
}

%end

// ============================================================
//  6. 防撤回 + 自定义提示
// ============================================================

@interface CMessageMgr : NSObject
- (void)onRevokeMsg:(id)arg;
- (void)AsyncOnAddMsg:(id)msg MsgWrap:(id)wrap;
@end

%hook CMessageMgr

- (void)onRevokeMsg:(id)arg {
    if (antiRevokeEnabled()) {
        // 防撤回开启：拦截撤回；是否显示提示语由「撤回提示」开关控制
        if (revokeToastEnabled()) {
            showRecallToast(revokeNoticeText());
        }
    } else {
        %orig;
    }
}

// ============================================================
//  7. 自动抢红包
// ============================================================

- (void)AsyncOnAddMsg:(id)msg MsgWrap:(id)wrap {
    %orig;
    if (!autoRedEnvelopEnabled()) return;
    [self xddHandleRedEnvelopMessage:wrap];
}

%new
- (void)xddHandleRedEnvelopMessage:(id)wrap {
    @try {
        NSInteger msgType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
        NSString *content = [wrap valueForKey:@"m_nsContent"];
        if (msgType != 49 || !content || [content rangeOfString:@"wxpay://"].location == NSNotFound) return;

        id payInfo = [wrap valueForKey:@"m_oWCPayInfoItem"];
        NSString *nativeUrl = [payInfo valueForKey:@"m_c2cNativeUrl"];
        if (!nativeUrl || nativeUrl.length == 0) return;

        NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"] ?: @"";
        NSString *toUsr = [wrap valueForKey:@"m_nsToUsr"] ?: @"";
        BOOL isGroup = [fromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
        BOOL isGroupSender = [toUsr rangeOfString:@"chatroom"].location != NSNotFound;

        // 过滤：群聊/单聊
        if (isGroup && !grabGroupChatEnabled()) return;
        if (!isGroup && !grabSingleChatEnabled()) return;
        if (isGroupSender) return; // 不抢自己发的

        // 解析 nativeUrl 里的参数
        NSString *query = nativeUrl;
        NSRange qRange = [nativeUrl rangeOfString:@"?"];
        if (qRange.location != NSNotFound) query = [nativeUrl substringFromIndex:qRange.location + 1];
        NSDictionary *urlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:query separator:@"&"];
        NSString *sendId = [urlDict objectForKey:@"sendid"];
        if (!sendId) return;

        // 防重复
        if (isSendIdGrabbed(sendId)) return;

        // 组装抢红包请求参数（简化版，仿 WeChatRedEnvelop）
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:sendId forKey:@"sendId"];
        [params setObject:([urlDict objectForKey:@"msgtype"] ?: @"1") forKey:@"msgType"];
        [params setObject:([urlDict objectForKey:@"channelid"] ?: @"1") forKey:@"channelId"];
        [params setObject:nativeUrl forKey:@"nativeUrl"];
        [params setObject:(isGroup ? fromUsr : toUsr) forKey:@"sessionUserName"];

        // 先查询红包状态（拿到 sign），再在响应里真正开抢
        [params setObject:@"0" forKey:@"agreeDuty"];
        [params setObject:@"0" forKey:@"inWay"];

        MMContext *context = [%c(MMContext) activeUserContext];
        WCRedEnvelopesLogicMgr *logicMgr = [context getService:NSClassFromString(@"WCRedEnvelopesLogicMgr")];
        if (!logicMgr) return;

        [logicMgr ReceiverQueryRedEnvelopesRequest:params];

        // 记住本次要抢的红包参数，等响应回来后开抢
        static NSMutableDictionary *pending = nil;
        if (!pending) pending = [NSMutableDictionary dictionary];
        [pending setObject:params forKey:sendId];

        // 标记已抢（防重复）
        markSendIdGrabbed(sendId);
    } @catch (NSException *e) {
        // 解析失败就跳过，绝不影响微信正常运行
    }
}

%end

%hook WCRedEnvelopesLogicMgr

// 红包查询响应回来 → 延迟后真正开抢
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    @try {
        if (!autoRedEnvelopEnabled()) return;
        int cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] intValue];
        if (cgiCmdid != 3) return; // 只处理参数查询响应

        id retText = [arg1 valueForKey:@"retText"];
        NSData *buffer = [retText valueForKey:@"buffer"];
        if (!buffer) return;
        NSString *responseString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
        NSDictionary *responseDict = [self xddJsonToDict:responseString];

        NSInteger receiveStatus = [[responseDict objectForKey:@"receiveStatus"] integerValue];
        NSInteger hbStatus = [[responseDict objectForKey:@"hbStatus"] integerValue];
        if (receiveStatus == 2) return; // 已抢过
        if (hbStatus == 4) return;      // 已被抢完

        // 从请求里拿回之前存的参数
        id reqText = [arg2 valueForKey:@"reqText"];
        NSData *reqBuffer = [reqText valueForKey:@"buffer"];
        NSString *reqString = reqBuffer ? [[NSString alloc] initWithData:reqBuffer encoding:NSUTF8StringEncoding] : @"";
        NSDictionary *reqDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:reqString separator:@"&"];
        NSString *nativeUrl = [[reqDict objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        if (!nativeUrl) return;

        NSString *sendId = [reqDict objectForKey:@"sendid"];
        if (!sendId) return;

        // 延迟秒数（加一点随机，降低被判定外挂的概率）
        NSInteger delay = grabDelaySeconds();
        if (delay < 0) delay = 0;
        int jitter = arc4random_uniform(7); // 0~6
        double totalDelay = delay + jitter * 0.1;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(totalDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                MMContext *context = [%c(MMContext) activeUserContext];
                WCRedEnvelopesLogicMgr *logicMgr = [context getService:NSClassFromString(@"WCRedEnvelopesLogicMgr")];
                if (!logicMgr) return;

                // 组装开抢参数
                NSMutableDictionary *grabParams = [NSMutableDictionary dictionary];
                [grabParams setObject:sendId forKey:@"sendId"];
                [grabParams setObject:([reqDict objectForKey:@"msgtype"] ?: @"1") forKey:@"msgType"];
                [grabParams setObject:([reqDict objectForKey:@"channelid"] ?: @"1") forKey:@"channelId"];
                [grabParams setObject:nativeUrl forKey:@"nativeUrl"];
                if ([responseDict objectForKey:@"timingIdentifier"]) {
                    [grabParams setObject:[responseDict objectForKey:@"timingIdentifier"] forKey:@"timingIdentifier"];
                }
                [grabParams setObject:@"0" forKey:@"agreeDuty"];

                [logicMgr OpenRedEnvelopesRequest:grabParams];
            } @catch (NSException *e) {}
        });
    } @catch (NSException *e) {}
}

%new
- (NSDictionary *)xddJsonToDict:(NSString *)json {
    if (!json) return @{};
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [obj isKindOfClass:[NSDictionary class]] ? obj : @{};
}

%end
