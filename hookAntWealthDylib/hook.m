//
//  hook.m
//  hookAntWealthDylib
//
//  Created by 独立日 on 2020/8/6.
//  Copyright © 2020 独立日. All rights reserved.
//

#import "hook.h"
#import "DTRpcOperation.h"
#import "MBProgressHUD.h"
#import <UIKit/UIKit.h>

@implementation hook
static NSMutableDictionary *fundSharesDic;

// 获取请求返回数据
+(void)hookWithOperation:(DTRpcOperation *)operation{
    @try {
        NSDictionary *allHTTPHeaderFields = operation.request.allHTTPHeaderFields;
        NSString *type = allHTTPHeaderFields[@"Operation-Type"];
        
        
        if([type isEqualToString: @"com.alipay.wealthbffweb.fund.optional.queryV3"]){
            // 计算收益
            [self calculateIncomeWithOperation:operation];
        }else if([type isEqualToString: @"com.alipay.wealthbffweb.fund.commonAsset.queryAssetDetail"]){
            // 获取份额
            [self getFundSharesWithOperation:operation];
        }
    } @catch (NSException *exception) {
        NSLog(@"error:%@", exception);
    }
}


#pragma mark - holdingMap
// 份额 本地保存路径
+ (NSString *)FundSharesDicPath {
    static NSString *path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        path = [documentsDirectory stringByAppendingPathComponent:@"FundSharesDic.plist"];
    });
    return path;
}

+ (void)loadFundSharesDic {
    NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithContentsOfFile:self.FundSharesDicPath];
    if (!dic) {
        dic = NSMutableDictionary.dictionary;
    }
    fundSharesDic = dic;
}

/// 读取本地保存的份额
+ (NSString *)getFundSharesWithFundCode:(NSString *)fundCode { //fundCode 基金代码
    if (fundSharesDic == nil) {
        [self loadFundSharesDic];
    }
    return fundSharesDic[fundCode];
}


#pragma mark - handle
// 计算收益
+ (void)calculateIncomeWithOperation:(DTRpcOperation *)operation {
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:operation.responseData options:NSJSONReadingMutableLeaves error:nil];
    if (json && [json isKindOfClass:NSDictionary.class]) {
        // 解析数据
        NSMutableDictionary *m_json = [json mutableCopy];
        NSMutableDictionary *result = [m_json[@"result"] mutableCopy];
        NSArray *optionalList = result[@"optionalList"];
        NSMutableArray *modifyList = NSMutableArray.array;
        NSMutableArray *incomes = NSMutableArray.array;

        for (NSDictionary *obj in optionalList) {
            NSMutableDictionary *model = [obj mutableCopy];
            BOOL holdingPosition = [model[@"holdingPosition"] boolValue];
            if (holdingPosition) {
                // 获取份额
                NSString *value = [self getFundSharesWithFundCode:model[@"fundCode"]];

                // 获取时间
                NSString *netValueReportDate = model[@"netValueReportDate"];
                NSString *estimateDate = model[@"estimateDate"];

                // 有效份额 才参与统计
                if (value.doubleValue > 0) {
                    NSMutableArray *contentTags = NSMutableArray.array;

                    // 预估时间不等于网络净值时间时 统计收益
                    if ([netValueReportDate isKindOfClass:NSString.class] &&
                        [estimateDate isKindOfClass:NSString.class]) {
                        NSString *netValue = model[@"netValue"];
                        if (
                            ![netValueReportDate isEqualToString:estimateDate]) {
                            NSString *estimateNetValue = model[@"estimateNetValue"];
                            // 没有预估时 忽略收益
                            if (estimateNetValue.doubleValue && netValue.doubleValue) {
                                double income = (estimateNetValue.doubleValue - netValue.doubleValue) * value.doubleValue;
                                [incomes addObject:@(income)];
                                [contentTags addObject:@{
                                     @"visible": @YES,
                                     @"text": [NSString stringWithFormat:@"收益:%0.2f", income],
                                     @"type": @"BULL_FUND",
                                }];
                            }
                        } else {
                            NSString *dayOfGrowth = model[@"dayOfGrowth"];
                            if (dayOfGrowth.length) {
                                NSString *modifyWorth = [NSString stringWithFormat:@"%0.4f",netValue.doubleValue / (1 + dayOfGrowth.doubleValue)];
                                double income = (netValue.doubleValue - modifyWorth.doubleValue) * value.doubleValue;
                                [incomes addObject:@(income)];
                                [contentTags addObject:@{
                                     @"visible": @YES,
                                     @"text": [NSString stringWithFormat:@"净收:%0.2f", income],
                                     @"type": @"BULL_FUND",
                                }];
                            }
                        }
                    }
                    if (!contentTags.count) {
                        [contentTags addObject:@{
                             @"visible": @YES,
                             @"text": [NSString stringWithFormat:@"份额:%@", value],
                             @"type": @"BULL_FUND",
                        }];
                    }
                    model[@"contentTags"] = contentTags;
                } else {
                    model[@"contentTags"] = @[
                        @{
                            @"visible": @YES,
                            @"text": @"点击读取份额",
                            @"type": @"BULL_FUND",
                        },
                    ];
                }
            }
            [modifyList addObject:model];
        }

        result[@"optionalList"] = modifyList;
        m_json[@"result"] = result;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:m_json options:NSJSONWritingPrettyPrinted error:nil];
        operation.responseData = jsonData;

        if (incomes.count) {
            NSDecimalNumber *sum = [incomes valueForKeyPath:@"@sum.doubleValue"];
            NSString *desc = [NSString stringWithFormat:@"有效统计%ld只,当前总收益%0.2f", incomes.count, sum.doubleValue];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UILabel *label = UILabel.new;
                UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
                label.frame = CGRectMake(20, CGRectGetMaxY(keyWindow.frame) - 118, CGRectGetMaxX(keyWindow.frame) - 40, 40);
                label.layer.cornerRadius = 5.f;
                label.layer.masksToBounds = YES;
                label.backgroundColor = [UIColor redColor];
                label.text = desc;
                label.textAlignment = NSTextAlignmentCenter;
                label.textColor = UIColor.whiteColor;
                label.font = [UIFont systemFontOfSize:16];
                [keyWindow addSubview:label];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [label removeFromSuperview];
                });
            });
        }
    }
}

// 获取份额
+ (void)getFundSharesWithOperation:(DTRpcOperation *)operation {
    
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:operation.responseData options:NSJSONReadingMutableLeaves error:nil];
       if (json && [json isKindOfClass:NSDictionary.class]) {
         // 解析数据
                 NSMutableDictionary *result = json[@"result"];
                 NSString *availableShare = result[@"availableShare"];
         //        设置本地记录份额
                 if (availableShare.doubleValue > 0) {
                     NSString *fundCode = result[@"fundCode"];
                     if (fundSharesDic == nil) {
                            [self loadFundSharesDic];
                        }
                        fundSharesDic[fundCode] = availableShare;
                        [fundSharesDic writeToFile:self.FundSharesDicPath atomically:YES];
            }
       }
}
@end
