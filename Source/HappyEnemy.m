//
//  HappyEnemy.m
//  PivotVividGGJ14
//
//  Created by Benjamin Encz on 26/01/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "HappyEnemy.h"

@implementation HappyEnemy

- (id)init {
    self = [super initWithPlist:@"happymask_default.plist"];
    
    if (self) {
        [self addAnimationwithDelayBetweenFrames:1/30.f name:@"happymask"];
        [self setFrame:@"happymask0001.png"];
        [self runAnimation:@"happymask"];
        self.moodToKill = @"happy";
    }
    
    return self;
}

@end
