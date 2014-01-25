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
#import "Hero.h"

@implementation Gameplay {
    CCNode *_contentNode;
    CCPhysicsNode *_physicsNode;
    CCNode *_level;
    CCNode *_hero;
    
    // array of masks the player has; masks are required for mood changes
    NSMutableArray *_masks;
    
    // determines if player can jump
    BOOL _onGround;
    
    // current mood
    int _currentMoodIndex;
    
    // array of all blocks
    NSMutableArray *_blocks;
    
    // array of all moods
    NSArray *_moods;
    
    // position of touch start (recorded in touchBegan)
    CGPoint _touchStartPosition;
    
    // stores three version of the scrolling background (to allow endless scrolling)
    NSArray *_backgrounds;
    
    // determines the goal position of this level, when this is reached it is consisdered a win!
    int levelGoal;
}

// distance between masks
static const float DISTANCE_PER_MASK = 28.f;

// amount of initial masks
static const int INITIAL_MASKS = 2;

#pragma mark - Init

- (void)didLoadFromCCB {
    // load initial background
    NSString *spriteFrameName = @"art/sad_background.png";
    CCSpriteFrame* spriteFrame = [CCSpriteFrame frameWithImageNamed:spriteFrameName];

    // position backgrounds
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
    
    // load first level
    _level = [CCBReader load:@"Level1"];
    
    levelGoal = _level.contentSize.width - 300;
    
    // collition type for hero
    _hero.physicsBody.allowsRotation = FALSE;
    _hero.physicsBody.collisionType = @"hero";
    
    // load level into physics node, setup ourselves as physics delegate
    [_physicsNode addChild:_level];
    _physicsNode.collisionDelegate = self;
//    _physicsNode.debugDraw = TRUE;
    
    // move hero continously
    CCActionMoveBy *moveBy = [CCActionMoveBy actionWithDuration:2.f position:ccp(400, 0)];
    CCActionRepeatForever *repeatMovement = [CCActionRepeatForever actionWithAction:moveBy];
    [_hero runAction:repeatMovement];
    
    // setup a camera to follow the hero
    CCActionFollowGGJ *followHero = [CCActionFollowGGJ actionWithTarget:_hero worldBoundary:_level.boundingBox];
    [_contentNode runAction:followHero];
    
    // activate user interaction to grab touches
    self.userInteractionEnabled = TRUE;
    
    
    // collect all blocks in blocks array
    _blocks = [NSMutableArray array];
    
    for (CCNode *child in _level.children) {
        if ([child isKindOfClass:[GroundBlock class]]) {
            [_blocks addObject:child];
        }
    }
    
    _masks = [NSMutableArray array];
    
    // setup all moods
    Mood *happy = [[Mood alloc] init];
    happy.moodPrefix = @"happy";
    
    Mood *angry = [[Mood alloc] init];
    angry.moodPrefix = @"angry";
    
    Mood *calm = [[Mood alloc] init];
    calm.moodPrefix = @"calm";
    
    Mood *fear = [[Mood alloc] init];
    fear.moodPrefix = @"fear";
    
    _moods = @[happy, angry, calm, fear];
    

    // preload audio
    OALSimpleAudio *audio = [OALSimpleAudio sharedInstance];
    audio.preloadCacheEnabled = TRUE;
    
    for (Mood *mood in _moods) {
        NSString *filename = [NSString stringWithFormat:@"%@.mp3", mood.moodPrefix];
        [audio preloadEffect:filename];
    }
    
    // initialize mood & maksk
    [self switchMood];
    [self initializeMask];
}

- (void)initializeMask {
    for (int i = 0; i < INITIAL_MASKS; i++) {
        Mask *mask = (Mask*)[CCBReader load:@"Mask"];
        mask.position = _hero.position;
        [_level addChild:mask];
        [_masks addObject:mask];
    }
}

#pragma mark - Update

- (void)update:(CCTime)delta {
    // GJ hack, to forbid rotation
    _hero.physicsBody.angularVelocity = 0.f;
    _hero.rotation = 0.f;
    
    
    if ((_hero.boundingBox.origin.y + _hero.boundingBox.size.height) < 0) {
        // when the hero falls -> game over
        [self endGame];
    }
    
    if (_hero.position.x >= levelGoal) {
        [self winGame];
    }
    
    // endless scrolling for backgrounds
    for (CCSprite *bg in _backgrounds) {
        bg.position = ccp(bg.position.x - 50 * delta, bg.position.y);
        if (bg.position.x < -1 * (bg.contentSize.width)) {
            bg.position = ccp(bg.position.x + (bg.contentSize.width*2)-2, 0);
        }
    }
    
    // make masks follow the player
    for (int i = 0; i < [_masks count]; i++) {
        Mask *mask = _masks[i];
        mask.position = ccp(_hero.position.x - (DISTANCE_PER_MASK * (i+1)), _hero.position.y);
    }
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    _touchStartPosition = [touch locationInNode:self];
}

- (void)touchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint currentPos = [touch locationInNode:self];
    CGFloat distance = ccpDistance(currentPos, _touchStartPosition);
    
    if (distance > 20.f) {
        [self switchMood];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(jump) object:nil];
    }
    else {
        [self jump];
    }
}

- (void)removeOneMask {
    Mask *firstMask = _masks[0];
    CCActionMoveTo *moveTo = [CCActionMoveTo actionWithDuration:1.f position:ccp(-100, 400)];
    CCActionCallBlock *removeFromParent = [CCActionCallBlock actionWithBlock:^{
        [firstMask removeFromParent];
    }];
    
    CCActionEaseBounceOut *bounceOut = [CCActionEaseBounceOut actionWithAction:moveTo];
    CCActionSequence *sequence = [CCActionSequence actions:bounceOut, removeFromParent, nil];
    
    [firstMask runAction:sequence];
    [_masks removeObject:firstMask];
    
}

- (void)switchMood {
    if ([_masks count] == 0) {
        // mood changes are only possible with masks
        return;
    }
    
    // remove one mask
    [self removeOneMask];
    
    // set the new mood index
    _currentMoodIndex += 1;
    
    if (_currentMoodIndex >= [_moods count]) {
        _currentMoodIndex = 0;
    }
    
    Mood *newMood = _moods[_currentMoodIndex];
    
    // play new song for this mood
    OALSimpleAudio *audio = [OALSimpleAudio sharedInstance];
    [audio stopAllEffects];
    NSString *filename = [NSString stringWithFormat:@"%@.mp3", newMood.moodPrefix];
    [audio playEffect:filename loop:TRUE];
    
    
    // apply new mood to all blocks
    for (GroundBlock *block in _blocks) {
        [block applyMood:newMood];
    }
    
    // change background color for moods
    NSString *spriteFrameName = [NSString stringWithFormat:@"art/%@_background.png", newMood.moodPrefix];
    CCSpriteFrame* spriteFrame = [CCSpriteFrame frameWithImageNamed:spriteFrameName];
    
    for (CCSprite *bg in _backgrounds) {
        [bg setSpriteFrame:spriteFrame];
    }
}

- (void)jump {
    if (_onGround) {
        _onGround = FALSE;
        [_hero.physicsBody applyForce:ccp(0, 20000)];
    }
//    [self winGame];
}

#pragma mark - Loose / Win interation

- (void)endGame {
    // reload level
    CCScene *scene = [CCBReader loadAsScene:@"Gameplay"];
    [[CCDirector sharedDirector] replaceScene:scene];
}

- (void)winGame {
    CCLabelTTF *winLabel = [CCLabelTTF labelWithString:@"WELL DONE!" fontName:@"Arial"fontSize:40.f];
    winLabel.color = [CCColor blackColor];
    winLabel.positionType = CCPositionTypeNormalized;
    winLabel.position = ccp(0.5f, 0.5f);
    
    CCParticleSystem *particle = (CCParticleSystem *)[CCBReader load:@"ModeSwitch"];
    particle.positionType = CCPositionTypeNormalized;
    particle.position = ccp(0.5, 0.5);
    particle.autoRemoveOnFinish = TRUE;
    [self addChild:particle];
    
    [self addChild:winLabel];
    
    [_hero stopAllActions];
    
//    for (Mask *mask in _masks) {
//        [self removeOneMask];
//    }
}

#pragma mark - Collision Handling

-(void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero ground:(CCNode *)ground {
    if (pair.totalImpulse.y > fabs(pair.totalImpulse.x)) {
        // allow jump when we are on ground
        _onGround = TRUE;
    }
}

-(void)ccPhysicsCollisionPostSolve:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero enemy:(CCNode *)enemy {
    BasicEnemy *basicEnemy = (BasicEnemy*)enemy;
    NSString *moodPrefix = [_moods[_currentMoodIndex] moodPrefix];
    
    // test if enemy should be killed in current mood
    if ([basicEnemy.moodToKill isEqualToString:moodPrefix]) {
        CGPoint pos = basicEnemy.position;
        
        // particle effect for death
        CCParticleSystem *particle = (CCParticleSystem *)[CCBReader load:@"EnemyDies"];
        particle.position = basicEnemy.position;
        particle.autoRemoveOnFinish = TRUE;
        [_physicsNode addChild:particle];
        
        // add a mask
        [basicEnemy removeFromParentAndCleanup:TRUE];
        Mask *mask = (Mask*)[CCBReader load:@"Mask"];
        mask.position = pos;
        [_level addChild:mask];
        [_masks addObject:mask];
    } else {
        // if enemy does not die -> player dies
        [self endGame];
    }
}

-(void)ccPhysicsCollisionSeparate:(CCPhysicsCollisionPair *)pair hero:(CCNode *)hero ground:(CCNode *)ground {
    // once we're in the air, we're not on the ground anymore and cannot jump
    _onGround = FALSE;
}

@end
