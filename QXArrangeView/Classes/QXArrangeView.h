//
//  QXArrangeView.h
//  Expecta
//
//  Created by lqx on 2018/3/8.
//

#import <UIKit/UIKit.h>


#define BEGIN_ANIMATION_DUR 0.2
#define END_ANIMATION_DUR 0.2
#define TIMER_SPEED 0.05
#define STOP_ANIMATION 0.0
typedef NS_ENUM(NSInteger, MovingCellState){
    MovingCellStateInitial, //初始位置
    MovingCellStateReclosing,//重合
    MovingCellStateSide,     //在其他cell侧边地带
    
};
//开始
typedef void(^BeginBlock)(UICollectionViewCell *movingCell, UIView *snapshot);
//结束
typedef void(^EndBlock)(UICollectionViewCell *movingCell, UIView *snapshot);
//合并
typedef float (^MergeBlock)(NSIndexPath *oldPath, NSIndexPath *newPath, UIView *snapshortM, UIView *snapshortC);
//移除
typedef CGFloat (^MoveOutBlock)(NSIndexPath *oldPath, UIView *snapshort);
//合并结束
typedef void(^EndMergeBlock)(NSIndexPath *groupPath ,BOOL isCreate);
//能否合并
typedef BOOL(^isAbleMergeBlock)(id modelM, id modelC);



@interface QXArrangeView : UICollectionView

@property (nonatomic, strong)UICollectionViewCell *movingCell;
@property (nonatomic, strong)UICollectionViewCell *coveredCell;

@property (nonatomic, assign)CGFloat spaceHorizontal;//水平间距
@property (nonatomic, assign)CGFloat spaceVertical;//垂直间距
@property (nonatomic, assign)BOOL isAbleMoving;
@property (nonatomic, assign)BOOL isResoluteConflict;
@property (nonatomic, assign)BOOL isMerge;

/**collectionview数据源*/
@property (nonatomic, strong)NSArray<NSMutableArray *> *datas;
@property (nonatomic, strong)NSArray<NSIndexPath *> *excludePaths;
//block
@property (nonatomic, copy)BeginBlock beginBlock;
@property (nonatomic, copy)EndBlock     endBlock;
@property (nonatomic, copy)MergeBlock mergeBlock;
@property (nonatomic, copy)MoveOutBlock moveOutBlock;
@property (nonatomic, copy)EndMergeBlock endMergeBlock;
@property (nonatomic, copy)isAbleMergeBlock isAbleMergeBlock;
/**正在移动的cell状态*/
@property (nonatomic, assign)MovingCellState cellState;




/**
 *  截图被移动到新的indexPath范围，这时先更新数据源，重排数组，再将cell移至新位置
 *  @param indexPath 新的indexPath
 */
- (void)cellRelocatedToNewIndexPath:(NSIndexPath *)indexPath;

/*!
 @brief 返回一个给定view的截图
 @param inputView 要得到快照截图的视图
 */
- (UIView *)customSnapshotFromView:(UIView *)inputView;


/**
 *  拖拽结束，显示cell，并移除截图
 */
- (void)didEndDraging;
@end

