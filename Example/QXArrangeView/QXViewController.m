//
//  QXViewController.m
//  QXArrangeView
//
//  Created by Maoyis on 03/08/2018.
//  Copyright (c) 2018 Maoyis. All rights reserved.
//

#import "QXViewController.h"
#import <QXArrangeView/QXArrangeView.h>




@interface QXViewController ()<UICollectionViewDelegate, UICollectionViewDataSource>
@property (weak, nonatomic) IBOutlet QXArrangeView *arrangeView;
@property (nonatomic, strong) NSMutableArray *data;

@end

@implementation QXViewController


- (NSMutableArray *)data{
    if (!_data) {
        _data = [NSMutableArray new];
        for (int i=0; i<11; i++) {
            CGFloat red    = i*0.1;
            CGFloat green  = 1 - i*0.1;
            CGFloat blue   = 0.5*0.1*i;
            UIColor * color = [UIColor colorWithRed:red
                                              green:green
                                               blue:blue
                                              alpha:1];
            [_data addObject:color];
        }
    }
    return _data;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    //设置可移动
    self.arrangeView.isAbleMoving = YES;
    self.arrangeView.isMerge      = NO;
    self.arrangeView.datas        = @[self.data];
    [self registerCell];
    [self initLayout];
}


- (void)registerCell{
    [self.arrangeView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"UICollectionViewCell"];
}

- (void)initLayout{
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat unit = (width-20)/27;
    layout.itemSize                 = CGSizeMake(5*unit, 50);
    layout.minimumLineSpacing       = 2*unit;
    layout.minimumInteritemSpacing  = 2*unit;
    layout.sectionInset             = UIEdgeInsetsMake(20, 10, 0, 10);
    //设置交换间距
    self.arrangeView.spaceHorizontal      = unit;
    self.arrangeView.spaceVertical        = unit;
    self.arrangeView.collectionViewLayout = layout;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.data.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"UICollectionViewCell" forIndexPath:indexPath];
    
    cell.backgroundColor = self.data[indexPath.row];
    
    return cell;
    
}


@end
