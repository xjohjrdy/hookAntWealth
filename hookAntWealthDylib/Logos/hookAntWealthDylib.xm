// See http://iphonedevwiki.net/index.php/Logos

#import <UIKit/UIKit.h>
#import "hook.h"

%hook DTRpcOperation

- (void)finish {
   [hook hookWithOperation:self];
    return %orig;
}

%end
