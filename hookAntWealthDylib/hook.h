//
//  hook.h
//  hookAntWealthDylib
//
//  Created by 独立日 on 2020/8/6.
//  Copyright © 2020 独立日. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class DTRpcOperation;
@interface hook : NSObject

+ (void)hookWithOperation:(DTRpcOperation *)operation;
@end

NS_ASSUME_NONNULL_END
