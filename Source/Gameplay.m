//
//  Gameplay.m
//  PivotVividGGJ14
//
//  Created by Benjamin Encz on 24/01/14.
//  Copyright (c) 2014 Apportable. All rights reserved.
//

#import "Gameplay.h"
#import "CCActionFollowGGJ.h"
#import "GroundBlock.h"
#import "Mood.h"
#import "BasicEnemy.h"
#import "Mask.h"

@implementation Gameplay {
    CCPhysicsNode *_physicsNode;
    CCNode *_level;
    CCNode *_hero;
    CCNode *_contentNode;
    
    NSMutableArray *_masks;
    
    BOOL _onGround;
    
    int _currentMoodIndex;
    
    NSMutableArray *_blocks;
    NSArray *_moods;
    
    CGPoint _touchStartPosition;
    NSArray *_backgrounds;
}

#pragma mark - Init

- (void)didLoadFromCCB {
    NSString *spriteFrameName = @"art/sad_background.png";
    CCSpriteFrame* spriteFrame = [CCSpriteFrame frameWithImageNamed:spriteFrameName];

    CCSprite *bg1 = [CCSprite spriteWithSpriteFrame:spriteFrame];
    CCSprite *bg2 = [CCSprite spriteWithSpriteFrame:spriteFrame];
    CCSprite *bg3 = [CCSprite spriteWithSpriteFrame:spriteFrame];
    bg1.anchorPoint = ccp(0, 0);
    bg1.position = ccp(0, 0);
    bg2.anchorPoint = ccp(0, 0);
    bg2.position = ccp(bg1.contentSize.width-1, 0);
    bg3.anchorPoint = ccp(0, 0);
    bg3.position = ccp(2*bg1.contentSize.width-1, 0);
    _backgrounds = @[bg1, bg2, bg3];
    
    [self addChild:bg1 z:INT_MIN];
    [self addChild:bg2 z:INT_MIN];
    [self addChild:bg3 z:INT_MIN];
    
    _currentMoodIndex = 0;
    _level = [CCBReader load:@"Level1"];
    
    _hero.physicsBody.allowsRotation = FALSE;
    _hero.physicsBody.collisionType = @"hero";
    
    [_physicsNode addChild:_level];
    _physicsNode.collisionDelegate = self;
//    _physicsNode.debugDraw = TRUE;
    
    CCActionMoveBy *moveBy = [CCActionMoveBy actionWithDuration:2.f position:ccp(200, 0)];
    CCActionRepeatForever *repeatMovement = [CCActionRepeatForever actionWithAction:moveBy];
    [_hero runAction:repeatMovement];
    
    CCActionFollowGGJ *followHero = [CCActionFollowGGJ actionWithTarget:_hero worldBoundary:_level.boundingBox];
    [_contentNode runAction:followHero];
    
    self.userInteractionEnabled = TRUE;
    
    _blocks = [NSMutableArray array];
    
    for (CCNode *child in _level.children) {
        if ([child isKindOfClass:[GroundBlock class]]) {
            [_blocks addObject:child];
        }
    }
    
    OALSimpleAudio *audio = [OALSimpleAudio sharedInstance];
    audio.preloadCacheEnabled = TRUE;
    
    for (Mood *mood in _moods) {
        NSString *filename = [NSString stringWithFormat:@"%@.mp3", mood.moodPrefix];
        [audio preloadEffect:filename];
    }
    
    Mood *happy = [[Mood alloc] init];
    happy.moodPrefix = @"happy";
    
    Mood *angry = [[Mood alloc] init];
    angry.moodPrefix = @"angry";
    
    Mood *calm = [[Mood alloc] init];
    calm.moodPrefix = @"calm";
    
    Mood *fear = [[Mood alloc] init];
    calm.moodPrefix = @"fear";
    
    _moods = @[happy, angry, calm, fear];
    [self switchMood];
}

#pragma mark - Update

- (void)update:(CCTime)delta {
    _hero.physicsBody.angularVelocity = 0.f;
    _hero.rotation = 0.f;
    if ((_hero.boundingBox.origin.y + _hero.boundingBox.size.height) < 0) {
        [self endGame];
    }
    
    for (CCSprite *bg in _backgrounds) {
        bg.position = ccp(bg.position.x - 50*delta, bg.position.y);
        if (bg.position.x < -1 * (bg.contentSize.width)) {
            bg.position = ccp(bg.position.x + (bg.contentSize.width*2)-2, 0);
        }
    }
}

- (void)endGame {
    CCScene *scene = [CCBReader loadAsScene:@"Gameplay"];
    [[CCDirector sharedDirector] replaceScene:scene];
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    _touchStartPosition = [touch locationInNode:self];
}

- (void)touchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    
    CGPoint currentPos = [touch locationInNode:self];
    CGFloat distance = ccpDistance(currentPos, _touchStartPosition);
    if (distance > 20.f /*&& (slope < 1 || slope > -1) && _onGround*/) {
        [self switchMood];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jump) object:nil];

    }
    else {
        [self jump];
    }
}

- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event {

}

- (void)switchMood {
    _currentMoodIndex += 1;
    
    if (_currentMoodIndex >= [_moods count]) {
        _currentMoodIndex = 0;
    }
    
    Mood *newMood = _moods[_currentMoodIndex];
    
    OALSimpleAudio *audio = [OALSimpleAudio sharedInstance];
    [audio stopAllEffects];
    NSString *filename = [NSString stringWithFormat:@"%@.mp3", newMood.moodPrefix];
    [audio playEffect:filename loop:TRUE];
    
    for (GroundBlock *block in _blocks) {
        [block applyMood:newMood];
    }
}

- (void)jump {
    if (_onGround) {
        _onGround = FALSE;
        [_hero.physicsBody applyForce:ccp(0, 50000)];
    }
}

- (void)dash {
    CCActionMoveBy *moveBy = [CCActionMoveBy actionWithDuration:.5f position:ccp(25, 0)];
    [_hero runAction:moveBy];
}

#pragma mark - Collision Handling

-(void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero ground:(CCNode *)ground {
    CCLOG(@"x:%f y:%f", pair.totalImpulse.x, pair.totalImpulse.y);

    if (pair.totalImpulse.y > fabs(pair.totalImpulse.x)) {
        _onGround = TRUE;
    }
}

-(void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero mask:(CCNode *)mask {
    Mask *aMask = (Mask*)mask;
    [_masks addObject:aMask];
}

-(void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero enemy:(CCNode *)enemy {
    
    BasicEnemy *basicEnemy = (BasicEnemy*)enemy;
    
    NSString *moodPrefix = [_moods[_currentMoodIndex] moodPrefix];
    
    if ([basicEnemy.moodToKill isEqualToString:moodPrefix]) {
        CGPoint p = CGPointMake(20, 0);
        CGPoint pos = basicEnemy.position;
        [basicEnemy removeFromParentAndCleanup:TRUE];
        Mask *mask = [[Mask alloc] init];
        mask.position = ccpAdd(pos, p);
        [mask addChild:_level];
    } else {
        [self endGame];
    }
}

-(void)ccPhysicsCollisionSeparate:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero ground:(CCNode *)ground {
    _onGround = FALSE;
}


@end
