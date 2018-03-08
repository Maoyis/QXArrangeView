//
//  QXArrangeView.m
//  Expecta
//
//  Created by lqx on 2018/3/8.
//

#import "QXArrangeView.h"

//#import "DataModel.h"

#define SNAPSHOT_COLOR [UIColor clearColor]


typedef enum{
    RTSnapshotMeetsEdgeTop,
    RTSnapshotMeetsEdgeBottom,
}RTSnapshotMeetsEdge;


@interface QXArrangeView ()<UIGestureRecognizerDelegate>
/**记录手指所在的位置*/
@property (nonatomic, assign) CGPoint fingerLocation;
/**被选中的cell的新位置*/
@property (nonatomic, strong) NSIndexPath *relocatedIndexPath;
/**被选中的cell的原始位置*/
@property (nonatomic, strong) NSIndexPath *originalIndexPath;
/**对被选中的cell的截图*/
@property (nonatomic, weak) UIView *snapshot;
@property (nonatomic, weak) UIView *coverSnapshot;
/**自动滚动的方向*/
@property (nonatomic, assign) RTSnapshotMeetsEdge autoScrollDirection;

/**cell被拖动到边缘后开启，collectionView自动向上或向下滚动*/
@property (nonatomic, strong) CADisplayLink *autoScrollTimer;
@property (nonatomic, strong) UILongPressGestureRecognizer *lp;
@end
@implementation QXArrangeView{
    NSTimer *_timer;
    CGFloat _stopTime;
}


- (void)startTimer{
    _stopTime = 0;
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:TIMER_SPEED target:self selector:@selector(runTime) userInfo:nil repeats:YES];
    }
}
- (void)stopTime{
    _stopTime = 0;
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}


- (void)runTime{
    _stopTime += TIMER_SPEED;
    if (_stopTime>=STOP_ANIMATION && self.movingCell) {
        NSLog(@"判断开始");
        _stopTime = -1024;
        self.cellState = [self initIndexPaths:self.movingCell];
        if (self.datas.count == 0 || [self.datas[_relocatedIndexPath.section] count] == 0) {
            return;
        }
        id model = self.datas[_relocatedIndexPath.section][_relocatedIndexPath.row];
        id modelM = self.datas[_originalIndexPath.section][_originalIndexPath.row];
        if (self.cellState == MovingCellStateReclosing&&[self isMerge:modelM covModel:model]) {
            [self recoveredAnimation];
            [UIView animateWithDuration:0.1 animations:^{
                self.coverSnapshot.transform = CGAffineTransformMakeScale(1.2, 1.2);
            } completion:^(BOOL finished) {
                
            }];
        }else if (self.cellState == MovingCellStateSide){
            [self cellRelocatedToNewIndexPath:_relocatedIndexPath];
        }else{
            
        }
    }
    
}
- (void)recoveredAnimation{
    if (self.coveredCell&&!self.coverSnapshot) {
        UIView *snapshot = [self customSnapshotFromView:self.coveredCell];
        self.coverSnapshot = snapshot;
        self.coverSnapshot.frame = self.coveredCell.frame;
        self.coveredCell.hidden = YES;
        //self.coverSnapshot.backgroundColor = [UIColor whiteColor];
        [self addSubview:self.coverSnapshot];
        
    }
}

- (NSArray<NSIndexPath *> *)excludePaths{
    if (!_excludePaths) {
        _excludePaths = [NSArray new];
    }
    return _excludePaths;
}
#pragma mark==============** 加载View **====================
-(void)awakeFromNib{
    [super awakeFromNib];
    [self addLongPressGestureRecognizer];
}

- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout{
    if (self = [super initWithFrame:frame collectionViewLayout:layout]) {
        [self addLongPressGestureRecognizer];
    }
    return self;
}

- (void)addLongPressGestureRecognizer{
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressGestureRecognized:)];
    lp.minimumPressDuration = 0.5;//触发时间：1s
    lp.allowableMovement = 10;//默认10像素
    lp.delegate = self;
    self.lp = lp;
    [self addGestureRecognizer:lp];
}
#pragma mark - 返回一个给定view的截图.
- (UIView *)customSnapshotFromView:(UIView *)inputView {
    
    // Make an image from the input view.
    UIGraphicsBeginImageContextWithOptions(inputView.bounds.size, NO, 0);
    [inputView.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // Create an image view.
    UIView *snapshot = [[UIImageView alloc] initWithImage:image];
    snapshot.center = inputView.center;
    snapshot.layer.masksToBounds = NO;
    snapshot.layer.cornerRadius = 0.0;
    snapshot.layer.shadowOffset = CGSizeMake(-5.0, 0.0);
    snapshot.layer.shadowRadius = 5.0;
    snapshot.layer.shadowOpacity = 0.4;
    snapshot.backgroundColor = SNAPSHOT_COLOR;
    return snapshot;
}
#pragma mark==============** 长按拖动手势 **====================
- (void)longPressGestureRecognized:(id)sender{
    if (!self.isAbleMoving) {
        return;
    }
    UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)sender;
    UIGestureRecognizerState longPressState = longPress.state;
    //手指在collectionView中的位置
    _fingerLocation = [longPress locationInView:self];
    //手指按住位置对应的indexPath，可能为nil
    _relocatedIndexPath = [self indexPathForItemAtPoint:_fingerLocation];
    // if (!_relocatedIndexPath) return;  //点击区域非cell不响应
    
    switch (longPressState) {
        case UIGestureRecognizerStateBegan:{
            //手势开始，对被选中cell截图，隐藏原cell
            _originalIndexPath = [self indexPathForItemAtPoint:_fingerLocation];
            if (_originalIndexPath && (![self.excludePaths containsObject:_originalIndexPath])) {
                [self startTimer];
                [self cellSelectedAtIndexPath:_originalIndexPath];
            }
            break;
        }
        case UIGestureRecognizerStateChanged:{//点击位置移动，判断手指按住位置是否进入其它indexPath范围，若进入则更新数据源并移动cell
            _stopTime = 0;
            self.cellState = MovingCellStateInitial;
            if (!self.movingCell) return;
            [self handleCoveredSnapshot];
            [self isMoving];
            break;
        }
        default: {
            [self stopTime];
            if (!self.movingCell) return;
            //长按手势结束或被取消，移除截图，显示cell
            [self stopAutoScrollTimer];
            [self endMovinghandle];
            break;
        }
    }
}


#pragma mark==============** start **====================
/**
 *  cell被长按手指选中，对其进行截图，原cell隐藏
 */
- (void)cellSelectedAtIndexPath:(NSIndexPath *)indexPath{
    
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath] ;
    self.movingCell = cell;
    UIView *snapshot = [self customSnapshotFromView:cell];
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    CGRect winFrame = [self convertRect:self.movingCell.frame toView:win];
    //CGPoint center = [self convertPoint:_fingerLocation toView:win];
    snapshot.frame = winFrame;
    [win addSubview:snapshot];
    
    _snapshot = snapshot;
    cell.hidden = YES;
    [UIView animateWithDuration:BEGIN_ANIMATION_DUR animations:^{
        _snapshot.transform = CGAffineTransformMakeScale(1.0, 1.0);
        _snapshot.alpha = 0.7;
        
        if (self.beginBlock) {
            self.beginBlock(self.movingCell, snapshot);
        }
        // _snapshot.center = center;
    }];
}

#pragma mark==============** end **====================
- (void)endMovinghandle{
    self.cellState = [self initIndexPaths:self.movingCell];
    CGFloat animationDur = 0;
    if ([self snapshotIsMoveOutOfBounds]) {
        if (self.moveOutBlock) {
            animationDur = self.moveOutBlock(_originalIndexPath, _snapshot);
            self.cellState = MovingCellStateInitial;
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(animationDur * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.cellState == MovingCellStateReclosing && self.mergeBlock) {
            CGFloat animationDur = 0;
            //合并后位置
            __block NSIndexPath *groupPath = _relocatedIndexPath;
            if (_originalIndexPath.row<_relocatedIndexPath.row) {
                groupPath = [NSIndexPath indexPathForRow:_relocatedIndexPath.row-1 inSection:_relocatedIndexPath.section];
            }
            //合并前位置上的数据模型
            id model = self.datas[_relocatedIndexPath.section][_relocatedIndexPath.row];
            //返回外界合并动画的时间
            animationDur = self.mergeBlock(_originalIndexPath, _relocatedIndexPath, _snapshot, _coverSnapshot);
            [self handleCoveredSnapshot];
            if (animationDur>0) {//确保外界合并动画成功结束后执行
                animationDur += 0.1;//此处加上0.1秒，由于不知道系统交换位置用时
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(animationDur * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    //合并后位置上的数据模型
                    id modelEnd = self.datas[_relocatedIndexPath.section][groupPath.row];
                    BOOL isCreate = model!=modelEnd ? YES : NO;
                    if (self.endMergeBlock) {
                        self.endMergeBlock(groupPath, isCreate);
                    }
                    
                });
            }else{
                [self didEndDraging];
            }
            
        }else{
            [self handleCoveredSnapshot];
            [self didEndDraging];
            [self reloadData];
        }
        self.cellState = MovingCellStateInitial;
    });
}

- (void)handleCoveredSnapshot{
    if (self.coverSnapshot&&!CGRectContainsPoint(self.coverSnapshot.frame, _fingerLocation)) {
        [UIView animateWithDuration:0.3 animations:^{
            _coverSnapshot.transform = CGAffineTransformMakeScale(1.0, 1.0);
        } completion:^(BOOL finished) {
            self.coveredCell.hidden = NO;
            [self.coverSnapshot removeFromSuperview];
            self.coverSnapshot = nil;
            self.coveredCell = nil;
        }];
        
    }
}
/**
 *  拖拽结束，显示cell，并移除截图
 */
- (void)didEndDraging{
    self.movingCell.hidden = NO;
    self.movingCell.alpha = 0;
    
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    CGPoint center = [self convertPoint:self.movingCell.center toView:win];
    [UIView animateWithDuration:END_ANIMATION_DUR animations:^{
        _snapshot.center = center;
        self.movingCell.alpha = 1;
        if (self.endBlock) {
            self.endBlock(self.movingCell, _snapshot);
        }
    } completion:^(BOOL finished) {
        self.movingCell.hidden = NO;
        [_snapshot removeFromSuperview];
        _snapshot = nil;
        _originalIndexPath = nil;
        _relocatedIndexPath = nil;
        self.movingCell = nil;
    }];
}

#pragma mark==============** Moving **====================
- (void)isMoving{
    CGPoint center = _snapshot.center;
    UIWindow *win = [UIApplication sharedApplication].keyWindow;
    CGPoint fingerLocation = [self convertPoint:_fingerLocation toView:win];
    
    center.y = fingerLocation.y;
    center.x = fingerLocation.x ;
    _snapshot.center = center;
    //self.movingCell.center = center;
    //如果到了整个collectionView以外，就滚回原处
    if ([self checkIfSnapshotMeetsEdge]) {
        [self startAutoScrollTimer];
    }else{
        [self stopAutoScrollTimer];
    }
    
    
}
- (void)getActionHandleByCellState{
    self.cellState = [self initIndexPaths:self.movingCell];
    if (self.cellState == MovingCellStateReclosing) {
        if (self.mergeBlock) {
            self.mergeBlock(_originalIndexPath, _relocatedIndexPath, _snapshot, _coverSnapshot);
        }else{
            [self cellRelocatedToNewIndexPath:_relocatedIndexPath];
        }
    }else if (self.cellState == MovingCellStateSide){
        [self cellRelocatedToNewIndexPath:_relocatedIndexPath];
    }else{
        
    }
}

#pragma mark==============** 判断是否出界 **====================
/**
 * 判断视图是否被移除父视图
 */
- (BOOL)snapshotIsMoveOutOfBounds{
    CGPoint center = [[UIApplication sharedApplication].keyWindow convertPoint:self.snapshot.center toView:self];
    //中心点在视图内
    BOOL flag1 = CGRectContainsPoint(self.bounds, center);
    //有交集就行
    //    BOOL flag2 = CGRectIntersectsRect(self.movingL.frame, self.bounds);
    if (flag1) {
        return NO;
    }else{
        return YES;
    }
}

#pragma mark==============** cell当前位置状态判断处理 **====================
- (MovingCellState)getCellAnimationHandleState:(UICollectionViewCell *)curCell mergeIndex:(NSIndexPath *)mergeIndex
                                       leftTop:(NSIndexPath *)leftTop
                                       leftBot:(NSIndexPath *)leftBot
                                      rightTop:(NSIndexPath *)rightTop
                                      rightBot:(NSIndexPath *)rightBot{
    
    //超出末尾处理
    if ([self getCellToEndCell:curCell curIndex:_originalIndexPath mergeIndex:mergeIndex]) {
        return MovingCellStateSide;
    }
    //超出起始位置处理
    if ([self getCellToStartCell:curCell curIndex:_originalIndexPath mergeIndex:mergeIndex]) {
        return MovingCellStateSide;
    }
    //初始位置处理
    if ((mergeIndex.row == _originalIndexPath.row && mergeIndex.section == _originalIndexPath.section) && mergeIndex != nil) {
        return MovingCellStateInitial;
    }
    //合并处理
    if (mergeIndex) {
        [self showMergeAnimation:mergeIndex];
        _relocatedIndexPath = mergeIndex;
        return MovingCellStateReclosing;
    }else if (leftTop && (leftTop.row != _originalIndexPath.row)&& (leftTop.section == _originalIndexPath.section)){
        _relocatedIndexPath = leftTop;
        NSLog(@"交换位置1");
    }else if (leftBot && (leftBot.row != _originalIndexPath.row) && (leftBot.section == _originalIndexPath.section)){
        _relocatedIndexPath = leftBot;
        NSLog(@"交换位置2");
    }else if (rightTop && (rightTop.row != _originalIndexPath.row) && (rightTop.section == _originalIndexPath.section)){
        _relocatedIndexPath = rightTop;
        NSLog(@"交换位置3");
    }else if (rightBot && (rightBot.row != _originalIndexPath.row) && (rightBot.section == _originalIndexPath.section)){
        _relocatedIndexPath = rightTop;
        NSLog(@"交换位置4");
    }
    else{
        NSLog(@"返回初始位置");
        _relocatedIndexPath = _originalIndexPath;
        return MovingCellStateInitial;
    }
    return MovingCellStateSide;
}
/**
 * 初始化将要进行片变更的位置并确定将要展开的动作
 */
- (MovingCellState)initIndexPaths:(UICollectionViewCell *)curCell{
    CGPoint curCenter = [[UIApplication sharedApplication].keyWindow convertPoint:self.snapshot.center toView:self];
    //周围对应位置中心点
    CGPoint leftTopCenter = CGPointMake(curCenter.x+self.spaceHorizontal, curCenter.y-self.spaceVertical);
    CGPoint leftBotCenter = CGPointMake(curCenter.x+self.spaceHorizontal, curCenter.y+self.spaceVertical);
    
    CGPoint rightTopCenter = CGPointMake(curCenter.x-self.spaceHorizontal, curCenter.y-self.spaceVertical);
    CGPoint rightBotCenter = CGPointMake(curCenter.x-self.spaceHorizontal, curCenter.y+self.spaceVertical);
    //周围位置
    NSIndexPath *leftTop = [self indexPathForItemAtPoint:leftTopCenter];
    NSIndexPath *leftBot= [self indexPathForItemAtPoint:leftBotCenter];
    NSIndexPath *rightTop = [self indexPathForItemAtPoint:rightTopCenter];
    NSIndexPath *rightBot = [self indexPathForItemAtPoint:rightBotCenter];
    NSIndexPath *curIndex = _originalIndexPath;
    NSIndexPath *mergeIndex = [self indexPathForItemAtPoint:curCenter];
    //外界允许合并判断--默认只有相同区域可以合并(处于初始位置，不在相同区域，出在不可处理位置。不能合并)
    if (mergeIndex==curIndex || mergeIndex.section != _originalIndexPath.section || [self.excludePaths containsObject:mergeIndex]) {
        mergeIndex = nil;
    }
    //判断并处理周围位置
    return [self judgeIsAbleHandleMergeIndex:mergeIndex lpath:leftTop rpath:leftBot tpath:rightTop bpath:rightBot];
}


/**
 * 判断是否为可改变位置，并处理待操作位置
 */
- (MovingCellState )judgeIsAbleHandleMergeIndex:(NSIndexPath *)mergeIndex lpath:(NSIndexPath *)lpath rpath:(NSIndexPath *)rpath tpath:(NSIndexPath *)tpath bpath:(NSIndexPath *)bpath{
    NSInteger count = self.datas[_originalIndexPath.section].count;
    NSIndexPath *endPath = [NSIndexPath indexPathForRow:count-1 inSection:_originalIndexPath.section];
    if ([self.excludePaths containsObject:lpath]) {
        lpath = endPath;
    }
    if ([self.excludePaths containsObject:rpath]) {
        rpath = endPath;
    }
    if ([self.excludePaths containsObject:bpath]) {
        bpath = endPath;
    }
    if ([self.excludePaths containsObject:tpath]) {
        tpath = endPath;
    }
    return [self getCellAnimationHandleState:self.movingCell mergeIndex:mergeIndex leftTop:lpath leftBot:rpath rightTop:tpath rightBot:bpath];
}

/**
 * 判断是否超出末尾位置
 */
- (BOOL)getCellToEndCell:(UICollectionViewCell *)curCell curIndex:(NSIndexPath *)curIndex mergeIndex:(NSIndexPath *)mergeIndex{
    CGPoint curCenter = [[UIApplication sharedApplication].keyWindow convertPoint:self.snapshot.center toView:self];
    NSInteger count = self.datas[_originalIndexPath.section].count;
    UICollectionViewCell *endCell = [self cellForItemAtIndexPath:[NSIndexPath indexPathForRow:count-1 inSection:curIndex.section]];
    if (endCell && curCell != endCell && mergeIndex == nil) {
        if (curCenter.y>endCell.center.y+self.spaceVertical||(curCenter.y>endCell.center.y-self.spaceVertical&&curCenter.x>CGRectGetMaxX(endCell.frame))) {
            _relocatedIndexPath = [NSIndexPath indexPathForRow:count-1 inSection:curIndex.section];
            return YES;
        }else{
            NSLog(@"没超出末尾位置");
        }
    }
    return NO;
    
}
/**
 * 判断是否超出起始位置
 */
- (BOOL)getCellToStartCell:(UICollectionViewCell *)curCell curIndex:(NSIndexPath *)curIndex mergeIndex:(NSIndexPath *)mergeIndex{
    CGPoint curCenter = [[UIApplication sharedApplication].keyWindow convertPoint:self.snapshot.center toView:self];
    UICollectionViewCell *startCell = [self cellForItemAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:curIndex.section]];
    if (startCell && curCell != startCell && mergeIndex == nil) {
        if (curCenter.y<startCell.frame.origin.y-self.spaceVertical||(curCenter.y<startCell.center.y+self.spaceVertical&&curCenter.x<CGRectGetMinX(startCell.frame))) {
            _relocatedIndexPath = [NSIndexPath indexPathForRow:0 inSection:curIndex.section];
            return MovingCellStateSide;
        }else{
            NSLog(@"没超出起始位置");
        }
    }
    return NO;
}


/**
 * 合并截图准备，是否有动画现象
 */
- (void)showMergeAnimation:(NSIndexPath *)mergeIndex{
    id model = self.datas[mergeIndex.section][mergeIndex.row];
    id modelM = self.datas[_originalIndexPath.section][_originalIndexPath.row];
    if ([self isMerge:modelM covModel:model]) {
        self.coveredCell = [self cellForItemAtIndexPath:mergeIndex];
    }else{
        self.coveredCell = nil;
    }
}
#pragma mark==============** 能否合并 **====================
- (BOOL)isMerge:(id)curModel covModel:(id)covModel{
    if (self.isAbleMergeBlock) {
        return self.isAbleMergeBlock(curModel, covModel);
    }
    return NO;
}
#pragma mark -  检查截图是否到达整个collectionView的边缘，并作出响应

- (BOOL)checkIfSnapshotMeetsEdge{
    CGRect frame = [[UIApplication sharedApplication].keyWindow convertRect:_snapshot.frame toView:self];
    CGFloat minY = CGRectGetMinY(frame);
    CGFloat maxY = CGRectGetMaxY(frame);
    if (minY < self.contentOffset.y) {
        _autoScrollDirection = RTSnapshotMeetsEdgeTop;
        return YES;
    }
    if (maxY > self.bounds.size.height + self.contentOffset.y) {
        _autoScrollDirection = RTSnapshotMeetsEdgeBottom;
        return YES;
    }
    return NO;
}

#pragma mark - timer methods
/**
 *  创建定时器并运行
 */
- (void)startAutoScrollTimer{
    if (!_autoScrollTimer) {
        _autoScrollTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(startAutoScroll)];
        [_autoScrollTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
}
/**
 *  停止定时器并销毁
 */
- (void)stopAutoScrollTimer{
    if (_autoScrollTimer) {
        [_autoScrollTimer invalidate];
        _autoScrollTimer = nil;
    }
}

#pragma mark - 开始自动滚动

- (void)startAutoScroll{
    CGFloat pixelSpeed = 4;
    if (_autoScrollDirection == RTSnapshotMeetsEdgeTop) {//向下滚动
        if (self.contentOffset.y > 0) {//向下滚动最大范围限制
            [self setContentOffset:CGPointMake(0, self.contentOffset.y - pixelSpeed)];
            //_snapshot.center = CGPointMake(_snapshot.center.x, _snapshot.center.y - pixelSpeed);
        }
    }else{                                               //向上滚动
        if (self.contentOffset.y + self.bounds.size.height < self.contentSize.height) {//向下滚动最大范围限制
            [self setContentOffset:CGPointMake(0, self.contentOffset.y + pixelSpeed)];
            //_snapshot.center = CGPointMake(_snapshot.center.x, _snapshot.center.y + pixelSpeed);
        }
    }
    CGPoint center = [[UIApplication sharedApplication].keyWindow convertPoint:_snapshot.center toView:self];
    _relocatedIndexPath = [self indexPathForItemAtPoint:center];
    if (_relocatedIndexPath && ![_relocatedIndexPath isEqual:_originalIndexPath]) {
        [self cellRelocatedToNewIndexPath:_relocatedIndexPath];
    }
}
#pragma mark - 移动时更新位置数据
/**
 *  截图被移动到新的indexPath范围，这时先更新数据源，重排数组，再将cell移至新位置
 *  @param indexPath 新的indexPath
 */
- (void)cellRelocatedToNewIndexPath:(NSIndexPath *)indexPath{
    //处理当前indexpath
    NSIndexPath *newPath = [self exmainIndexPath:indexPath];
    if (!newPath) {
        return;
    }
    if ([newPath isEqual:_originalIndexPath] || newPath.section != _originalIndexPath.section) {
        return;
    }
    //更新数据源并返回给外部
    [self updateDataSource:newPath.row];
    //交换移动cell位置
    
    [self moveItemAtIndexPath:_originalIndexPath toIndexPath:newPath];
    //更新cell的原始indexPath为当前indexPath
    _originalIndexPath = newPath;
    
}

- (NSIndexPath *)exmainIndexPath:(NSIndexPath *)indexPath{
    if ([self.excludePaths containsObject:indexPath]) {
        NSIndexPath *newPath = nil;
        for (NSInteger i = indexPath.row-1; i>0; i--) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:indexPath.section];
            if (![self.excludePaths containsObject:path]) {
                newPath = path;
                break;
            }
        }
        return newPath;
    }else{
        return indexPath;
    }
}

- (void)updateDataSource:(NSInteger)newIndex{
    
    NSMutableArray *datas = self.datas[_originalIndexPath.section];
    id startData = datas[_originalIndexPath.row];
    [datas removeObject:startData];
    if (datas.count<=newIndex) {
        [datas addObject:startData];
    }else{
        [datas insertObject:startData atIndex:newIndex];
    }
    
}


#pragma mark==============** UIGestureRecognizerDelegate **================
/**
 * 一次手势动作，有可能触发多个手势时，这个接口询问这些手势能否并存。
 eg：一个横向的scrollview A，内有个竖向的自scrollview B，一次斜的swipe手势（本意是想横滑），可能只响应B的竖向滑动，你期望的A的横向却没发生。
 解决方案：在该接口中识别你的手势，并return YES。注意不要扩大化了
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    if ([otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]] &&
        [gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    
    return NO;
}
/**
 * 手势可能发生的条件，比如某些特殊情况下，不想让此手势发生，就return NO了。
 */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer{
    if ([gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
        //YES：去掉边缘手势，由于侧滑菜单为第三方不便改代码，此处
        return YES;
    }else if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    else if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    
    return NO;
}
/**
 * 有的手势之所以没发生，是因为它被别的手势阻止了。典型的如UITapGestureRecognizer手势，一个UITapGestureRecognizer永远不会阻止一个更高tap次数的UITapGestureRecognizer.
 */
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer{
    return NO;
}





- (void)dealloc{
    self.datas = nil;
    self.excludePaths = nil;
}


@end
