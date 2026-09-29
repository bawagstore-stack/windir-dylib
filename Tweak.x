#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSString *const kName     = @"420euro's Application";
static NSString *const kOwnerID  = @"Z3NXQY2bdP";
static NSString *const kSecret   = @"34afdd8daf83695b2dc9dbc2f82d5d926bd64d509a569d219bbede8f685deebc";
static NSString *const kVersion  = @"1.0";

static NSString *const kKeyStoreKey = @"KeyAuthActivatedKey";
static NSString *const kKeyExpiry   = @"KeyAuthKeyExpiry";
static NSString *const kDeviceIDKey = @"KeyAuthDeviceID";

@interface BawaGHandler : NSObject
@property (nonatomic, strong) UITextField *keyInput;
@property (nonatomic, strong) UIViewController *topVC;
@property (nonatomic, strong) UIView *overlayView;
+ (instancetype)sharedInstance;
- (void)activatePressed;
- (void)quitPressed;
@end

// ── Move Patch File to Real Paks Directory ───────────────────────────────────
static BOOL applyWorkingPakPatch() {
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
    
    // Hidden patch file path inside Frameworks
    NSString *binPath = [bundlePath stringByAppendingPathComponent:@"Frameworks/mypatch.bin"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:binPath]) {
        binPath = [bundlePath stringByAppendingPathComponent:@"mypatch.bin"];
    }
    
    // Official Game Paks folder inside App Bundle
    NSString *paksFolder = [bundlePath stringByAppendingPathComponent:@"Paks"];
    NSString *targetPak = [paksFolder stringByAppendingPathComponent:@"gamepatch_4.6.0.21552.pak"];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:binPath]) {
        NSError *err = nil;
        if ([fm fileExistsAtPath:targetPak]) {
            [fm removeItemAtPath:targetPak error:nil];
        }
        
        BOOL copied = [fm copyItemAtPath:binPath toPath:targetPak error:&err];
        NSLog(@"[BAWA G STORE] Pak Copy Status: %d | Error: %@", copied, err);
        return copied;
    }
    return NO;
}

static NSString *getDeviceID() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *did = [ud stringForKey:kDeviceIDKey];
    if (!did) {
        did = [[[NSUUID UUID] UUIDString] lowercaseString];
        [ud setObject:did forKey:kDeviceIDKey];
        [ud synchronize];
    }
    return did;
}

static BOOL hasValidKey() {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *key = [ud stringForKey:kKeyStoreKey];
    NSDate   *exp = [ud objectForKey:kKeyExpiry];
    if (!key || !exp) return NO;
    
    BOOL isValid = [exp timeIntervalSinceNow] > 0;
    if (isValid) {
        applyWorkingPakPatch();
    }
    return isValid;
}

static UIViewController *getTopViewController() {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (!window) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) { window = w; break; }
        }
    }
    UIViewController *topController = window.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

@implementation BawaGHandler
+ (instancetype)sharedInstance {
    static BawaGHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BawaGHandler alloc] init];
    });
    return instance;
}

- (void)activatePressed {
    NSString *enteredKey = [self.keyInput.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (enteredKey.length == 0) return;

    UIViewController *vc = self.topVC;

    NSURL *url = [NSURL URLWithString:@"https://keyauth.win/api/1.2/"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

    NSString *initData = [NSString stringWithFormat:@"type=init&name=%@&ownerid=%@&secret=%@&ver=%@",
                          kName, kOwnerID, kSecret, kVersion];
    req.HTTPBody = [initData dataUsingEncoding:NSUTF8StringEncoding];

    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"BAWA G STORE" message:@"Verifying..." preferredStyle:UIAlertControllerStyleAlert];
    [vc presentViewController:loading animated:YES completion:nil];

    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!data) return;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *sessionID = json[@"sessionid"];
        
        NSMutableURLRequest *licReq = [NSMutableURLRequest requestWithURL:url];
        licReq.HTTPMethod = @"POST";
        [licReq setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString *licData = [NSString stringWithFormat:@"type=license&key=%@&hwid=%@&sessionid=%@&name=%@&ownerid=%@",
                             enteredKey, getDeviceID(), sessionID, kName, kOwnerID];
        licReq.HTTPBody = [licData dataUsingEncoding:NSUTF8StringEncoding];

        [[[NSURLSession sharedSession] dataTaskWithRequest:licReq completionHandler:^(NSData *lData, NSURLResponse *lResp, NSError *lErr) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:NO completion:^{
                    NSDictionary *lJson = [NSJSONSerialization JSONObjectWithData:lData options:0 error:nil];
                    if ([lJson[@"success"] boolValue]) {
                        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                        [ud setObject:enteredKey forKey:kKeyStoreKey];
                        [ud setObject:[NSDate dateWithTimeIntervalSinceNow:30 * 24 * 60 * 60] forKey:kKeyExpiry];
                        [ud synchronize];

                        applyWorkingPakPatch();

                        UIAlertController *succAlert = [UIAlertController alertControllerWithTitle:@"Success!" message:@"License Verified! Re-open game to load skins." preferredStyle:UIAlertControllerStyleAlert];
                        [succAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                            exit(0);
                        }]];
                        [vc presentViewController:succAlert animated:YES completion:nil];
                    }
                }];
            });
        }] resume];
    }] resume];
}

- (void)quitPressed { exit(0); }
@end

static void showCustomBawaGPopup(void) {
    UIViewController *topVC = getTopViewController();
    if (!topVC) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showCustomBawaGPopup();
        });
        return;
    }

    UIView *overlayView = [[UIView alloc] initWithFrame:topVC.view.bounds];
    overlayView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.65];

    CGFloat cardWidth = 320, cardHeight = 260;
    UIView *cardView = [[UIView alloc] initWithFrame:CGRectMake((overlayView.frame.size.width - cardWidth)/2, (overlayView.frame.size.height - cardHeight)/2, cardWidth, cardHeight)];
    cardView.layer.cornerRadius = 20;
    cardView.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 20, cardWidth - 20, 28)];
    titleLabel.text = @"WELCOME TO BAWA G STORE";
    titleLabel.font = [UIFont boldSystemFontOfSize:17];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [cardView addSubview:titleLabel];

    UITextField *keyInput = [[UITextField alloc] initWithFrame:CGRectMake(20, 90, cardWidth - 40, 42)];
    keyInput.placeholder = @"Paste License Key";
    keyInput.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    keyInput.textColor = [UIColor whiteColor];
    keyInput.layer.cornerRadius = 10;
    keyInput.textAlignment = NSTextAlignmentCenter;
    [cardView addSubview:keyInput];

    BawaGHandler *handler = [BawaGHandler sharedInstance];
    handler.keyInput = keyInput;
    handler.topVC = topVC;

    UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    activateBtn.frame = CGRectMake(20, 150, cardWidth - 40, 42);
    activateBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.50 blue:0.98 alpha:1.0];
    [activateBtn setTitle:@"Activate License" forState:UIControlStateNormal];
    [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    activateBtn.layer.cornerRadius = 10;
    [activateBtn addTarget:handler action:@selector(activatePressed) forControlEvents:UIControlEventTouchUpInside];
    [cardView addSubview:activateBtn];

    [overlayView addSubview:cardView];
    [topVC.view addSubview:overlayView];
}

__attribute__((constructor))
static void init_bawa_g_store(void) {
    if (hasValidKey()) {
        applyWorkingPakPatch();
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showCustomBawaGPopup();
        });
    }
}
