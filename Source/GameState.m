//
//  GameState.m
//  PivotVividGGJ14
//
//  Created by Benjamin Encz on 26/01/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "GameState.h"

@implementation GameState {
    NSArray *_levels;
}

+ (instancetype)sharedInstance
{
    // structure used to test whether the block has completed or not
    static dispatch_once_t p = 0;
    
    // initialize sharedObject as nil (first call only)
    __strong static id _sharedObject = nil;
    
    // executes a block object once and only once for the lifetime of an application
    dispatch_once(&p, ^{
        _sharedObject = [[self alloc] init];
    });
    
    // returns the same object each time
    return _sharedObject;
}

- (id)init {
    self = [super init];
    
    if (self) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Levels" ofType:@"plist"];
        _levels = [NSArray arrayWithContentsOfFile:path];
        
        _currentLevelIndex = -1;
        
        while (YES == [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"Level_%d_unlocked", _currentLevelIndex+1]]) {
            _currentLevelIndex++;
        }
        
        if (_currentLevelIndex < [_levels count]) {
            [self loadLevel:_currentLevelIndex];
        } else {
            [self loadLevel:0];
        }
    }
    
    return self;
}

- (NSDictionary *)nextLevelInfo {
    NSDictionary *nextLevel = nil;
    
    if (self.currentLevelIndex+1 >= _levels.count) {
        nextLevel = _levels[0];
    } else {
        nextLevel = _levels[self.currentLevelIndex+1];
    }
    
    return nextLevel;
}

- (NSDictionary *)currentLevelInfo {
    return _levels[self.currentLevelIndex];;
}

- (void)loadNextLevel {
    NSString *levelString = [NSString stringWithFormat:@"Level_%d_unlocked", _currentLevelIndex+1];
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:levelString];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    int nextIndex = self.currentLevelIndex + 1;
    
    if (self.currentLevelIndex+1 >= _levels.count) {
        nextIndex = 0;
    }
    
    [self loadLevel:nextIndex];
}

- (void)loadLevel:(NSInteger)levelIndex {
    NSDictionary *nextLevel = _levels[levelIndex];
    _currentLevel = nextLevel[@"levelName"];
    _currentLevelIndex = levelIndex;
    self.currentLevelAttempts = 0;
}

- (BOOL)isNextLevelPremium {
    NSDictionary *nextLevel = [self nextLevelInfo];
    
    return [nextLevel[@"premium"] boolValue];
}

- (NSUInteger)levelCount {
    return [_levels count];
}

@end
