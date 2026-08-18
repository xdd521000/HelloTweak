//
//  Tweak.x — 小叮当（微信增强插件）
//  功能1：打开微信时弹出欢迎提示（会显示微信版本 + 防撤回接口状态）
//  功能2：微信防撤回（好友撤回的消息仍然保留）
//
//  兼容性设计：
//  - 弹窗用的全是系统公开 API，任何微信版本都能用
//  - 防撤回用的是微信十年稳定的标准接口 CMessageMgr onRevokeMsg:
//  - 如果某天微信改了内部代码，接口检测会显示"未找到"，
//    插件不会崩溃，只需要按新版接口更新即可
//

#import <UIKit/UIKit.h>

// ================= 功能1：欢迎弹窗（带版本体检） =================

static void showHelloPopup(void) {
    static BOOL shown = NO;
    if (shown) return;

    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    if (!window || !window.rootViewController) return;

    shown = YES;

    // 获取当前微信版本号
    NSString *wxVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (wxVersion.length == 0) wxVersion = @"未知";

    // 体检：检查防撤回要 hook 的接口在当前微信里是否存在
    // 存在 = 防撤回已就绪；不存在 = 微信改了内部代码，需要更新插件
    BOOL revokeHookReady = [NSClassFromString(@"CMessageMgr") instancesRespondToSelector:@selector(onRevokeMsg:)];
    NSString *status = revokeHookReady ? @"✅ 已就绪" : @"⚠️ 未找到接口（需更新插件）";

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"🔔 小叮当已生效"
                         message:[NSString stringWithFormat:@"微信版本：%@\n防撤回接口：%@\n\n设备：iPhone 14 Pro Max\n系统：iOS 16.2\n越狱：Dopamine", wxVersion, status]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];

    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

// %ctor：插件加载时自动运行，分几次尝试弹窗确保窗口就绪
%ctor {
    for (NSInteger i = 0; i < 5; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * (i + 1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showHelloPopup();
        });
    }
}

// ================= 功能2：防撤回 =================
//
// CMessageMgr 是微信的消息管理器（私有类，编译器不认识，手动声明）
// 微信收到"有人撤回消息"的通知时，会调用它的 onRevokeMsg: 方法
// 我们把这个方法拦下来、不执行原始逻辑，撤回就失效了
//

@interface CMessageMgr : NSObject
- (void)onRevokeMsg:(id)arg;
@end

%hook CMessageMgr

- (void)onRevokeMsg:(id)arg {
    // ★ 关键：不调用 %orig，撤回通知被拦截，消息原样保留
    // 如果这个接口在当前微信版本里不存在，Logos 会自动跳过，不会导致微信崩溃
}

%end
