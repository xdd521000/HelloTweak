//
//  HelloTweak.x
//  第一个越狱插件：打开"设置"App 时，弹出欢迎提示框
//
//  ★ Logos 语法三大关键词 ★
//    %hook 类名    —— 开始"钩住"一个类（拦截它的方法）
//    %orig         —— 调用被替换方法的"原始实现"（必须先调用，保证原功能正常）
//    %end          —— 结束钩子
//
//  学习顺序：先看懂这段，再去看 README 的逐行讲解
//

#import <UIKit/UIKit.h>

// PSListController 是"设置"App 的私有类，编译器不认识它，所以手动声明一下
// （"设置"里每一个页面都是这个类的子类）
@interface PSListController : UITableViewController
@end

// static 静态变量：整个 App 生命周期内只初始化一次
// 这里用来记录"已经弹过窗了"，保证提示只出现一次
static BOOL alertShown = NO;

%hook PSListController

// 页面完全显示出来后调用（此时窗口已经就绪，适合弹窗）
- (void)viewDidAppear:(BOOL)animated {
    %orig; // ① 先执行原始的 viewDidAppear，保证页面正常显示

    // ② 如果已经弹过提示，就直接返回
    if (alertShown) return;
    alertShown = YES;

    // ③ 创建弹窗（UIAlertController 是系统自带的弹窗控件）
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"🎉 HelloTweak 已生效"
                         message:@"这是你的第一个越狱插件！\n\n设备：iPhone 14 Pro Max\n系统：iOS 16.2\n越狱：Dopamine"
                  preferredStyle:UIAlertControllerStyleAlert];

    // 加一个"知道了"按钮
    [alert addAction:[UIAlertAction actionWithTitle:@"知道了"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];

    // ④ 找到"设置"App 的主窗口，把弹窗显示出来
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    [window.rootViewController presentViewController:alert animated:YES completion:nil];
}

%end
