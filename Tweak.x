/*
 * KeyAuth iOS Integration Tweak
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// ── KeyAuth Credentials ──────────────────────────────────────────────────────
static NSString *const kName     = @"420euro's Application";
static NSString *const kOwnerID  = @"Z3NXQY2bdP";
static NSString *const kSecret   = @"34afdd8daf83695b2dc9dbc2f82d5d926bd64d509a569d219bbede8f685deebc";
static NSString *const kVersion  = @"1.0";

static NSString *const kKeyStoreKey = @"KeyAuthActivatedKey";
static NSString *const kKeyExpiry   = @"KeyAuthKeyExpiry";
static NSString *const kDeviceIDKey = @"KeyAuthDeviceID";
// ─────────────────────────────────────────────────────────────────────────────

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
    return [exp timeIntervalSinceNow] > 0;
}

static void showKeyAuthAlert(UIViewController *vc) {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"License Verification"
        message:@"Enter your KeyAuth license key to continue."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Paste license key";
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];

    UIAlertAction *activate = [UIAlertAction
        actionWithTitle:@"Activate"
        style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {

        NSString *key = [[alert.textFields.firstObject.text
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];

        if (key.length == 0) {
            UIAlertController *err = [UIAlertController
                alertControllerWithTitle:@"Error"
                message:@"Please paste your license key."
                preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) { showKeyAuthAlert(vc); }];
            [err addAction:ok];
            [vc presentViewController:err animated:YES completion:nil];
            return;
        }

        UIAlertController *loading = [UIAlertController
            alertControllerWithTitle:@"KeyAuth"
            message:@"Validating key…"
            preferredStyle:UIAlertControllerStyleAlert];
        [vc presentViewController:loading animated:YES completion:nil];

        // KeyAuth API Endpoint Call
        NSString *deviceID = getDeviceID();
        NSURL *url = [NSURL URLWithString:@"https://keyauth.win/api/1.2/"];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];

        NSString *postData = [NSString stringWithFormat:@"type=license&key=%@&hwid=%@&name=%@&ownerid=%@&secret=%@&ver=%@",
                              key, deviceID, kName, kOwnerID, kSecret, kVersion];
        req.HTTPBody = [postData dataUsingEncoding:NSUTF8StringEncoding];
        req.timeoutInterval = 15;

        [[[NSURLSession sharedSession] dataTaskWithRequest:req
            completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:NO completion:^{

                    if (err || !data) {
                        UIAlertController *netErr = [UIAlertController
                            alertControllerWithTitle:@"Connection Error"
                            message:@"Network error. Check your connection."
                            preferredStyle:UIAlertControllerStyleAlert];
                        [netErr addAction:[UIAlertAction actionWithTitle:@"Retry"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) { showKeyAuthAlert(vc); }]];
                        [vc presentViewController:netErr animated:YES completion:nil];
                        return;
                    }

                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    BOOL success = [json[@"success"] boolValue];

                    if (!success) {
                        NSString *msg = json[@"message"] ?: @"Invalid key.";
                        UIAlertController *invalid = [UIAlertController
                            alertControllerWithTitle:@"Activation Failed"
                            message:msg
                            preferredStyle:UIAlertControllerStyleAlert];
                        [invalid addAction:[UIAlertAction actionWithTitle:@"Try Again"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) { showKeyAuthAlert(vc); }]];
                        [vc presentViewController:invalid animated:YES completion:nil];
                        return;
                    }

                    // Key is valid — Save session (Default 30 days expiry)
                    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
                    [ud setObject:key forKey:kKeyStoreKey];
                    NSDate *expDate = [NSDate dateWithTimeIntervalSinceNow:30 * 24 * 60 * 60];
                    [ud setObject:expDate forKey:kKeyExpiry];
                    [ud synchronize];

                    UIAlertController *successAlert = [UIAlertController
                        alertControllerWithTitle:@"Success"
                        message:@"License activated successfully!"
                        preferredStyle:UIAlertControllerStyleAlert];
                    [successAlert addAction:[UIAlertAction actionWithTitle:@"Enter App"
                        style:UIAlertActionStyleDefault handler:nil]];
                    [vc presentViewController:successAlert animated:YES completion:nil];
                }];
            });
        }] resume];
    }];

    UIAlertAction *quit = [UIAlertAction
        actionWithTitle:@"Quit"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            exit(0);
        }];

    [alert addAction:activate];
    [alert addAction:quit];
    [vc presentViewController:alert animated:YES completion:nil];
}

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (hasValidKey()) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            showKeyAuthAlert(self);
        });
    });
}

%end
