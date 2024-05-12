//
//  HKCollectionAnimationController.swift
//  HKLayoutDemo
//
//  Created by ALPS on 2024/5/12.
//  Copyright © 2024 Edward. All rights reserved.
//

import UIKit

class HKCollectionAnimationController: UIViewController {
    private var dataSource: [HWTItemModel] = [HWTItemModel]()

    override func viewDidLoad() {
        super.viewDidLoad()
        makeData()
        self.view.backgroundColor = UIColor.white
        self.view.addSubview(self.collectionView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.collectionView.frame = self.view.bounds
        self.collectionView.collectionViewLayout.invalidateLayout()
    }
    
    lazy var layout: HWTFlowLayout = {
        let layout = HWTFlowLayout()
        layout.scrollDirection = .vertical
        layout.column = 4
        return layout
    }()
    
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView.init(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = UIColor.clear
        collectionView.register(DefineCell.self, forCellWithReuseIdentifier: NSStringFromClass(DefineCell.self))
        return collectionView
    }()

}

// MARK: - UICollectionViewDataSource
extension HKCollectionAnimationController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if let cell: DefineCell = collectionView.dequeueReusableCell(withReuseIdentifier: NSStringFromClass(DefineCell.self), for: indexPath) as? DefineCell, self.dataSource.count > indexPath.item {
            let itemModel = self.dataSource[indexPath.item]
            cell.configOptionCellData(itemMode: itemModel)
            return cell
            
        } else {
            return UICollectionViewCell()
        }
    }

}

// MARK: - UICollectionViewDelegateFlowLayout
extension HKCollectionAnimationController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 90, height: 100)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
}

// MARK: - UICollectionViewDelegate
extension HKCollectionAnimationController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var item: HWTItemModel = self.dataSource[indexPath.item]
        guard let cell: DefineCell = collectionView.cellForItem(at: indexPath) as? DefineCell else { return }
        guard let children = self.dataSource[indexPath.item].children, children.count > 0 else { return }
            
        collectionView.bringSubviewToFront(cell)
        
        insertOrDeleteAnimation(collectionView: collectionView,
                                targetIndexPath: indexPath,
                                children: children,
                                isInsert: !item.isOpen) { (isFinish) in
            self.dataSource[indexPath.item].isOpen = !item.isOpen
        }
        
    }
    
    func insertOrDeleteAnimation(collectionView: UICollectionView,
                                 targetIndexPath: IndexPath,
                                 children: [HWTItemModel],
                                 isInsert: Bool,
                                 completion: ((Bool) -> Void)? = nil) {
        
        self.layout.targetIndexPath = targetIndexPath
        var index = (targetIndexPath.item + 1)
        var indexPaths: [IndexPath] = [IndexPath]()
        for insertItem in children {
            let indexPath = IndexPath.init(item: index, section: targetIndexPath.section)
            indexPaths.append(indexPath)
            if isInsert {
                self.dataSource.insert(insertItem, at: index)
            } else {
                self.dataSource.remove(at: targetIndexPath.item + 1)
            }
            index += 1
        }
        self.collectionView.allowsSelection = false
        
        
        UIView.animate(withDuration: 0.3) {
            CATransaction .begin()
            CATransaction.setAnimationDuration(0.3)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction.init(controlPoints: 0.75, 0, 0.25, 1.2))
            collectionView.performBatchUpdates({ [weak self] in
                guard let `self` = self else { return }
                if isInsert {
                    self.collectionView.insertItems(at: indexPaths)
                } else {
                    self.collectionView.deleteItems(at: indexPaths)
                }
            }) { [weak self] (isFinish) in
                guard let `self` = self else { return }
                self.collectionView.allowsSelection = true
                if let completion = completion {
                    completion(isFinish)
                }
            }
            CATransaction.commit()
        }
    }
}

//MARK: - HWTFlowLayout
class HWTFlowLayout: UICollectionViewFlowLayout {
    private let deleteIndexPaths: NSMutableArray = NSMutableArray()
    private let insertIndexPaths: NSMutableArray = NSMutableArray()
    private var tempTargetAttributes: UICollectionViewLayoutAttributes?
    var targetIndexPath: IndexPath?
    var column: NSInteger = 0
    
    //MARK: - UIUpdateSupportHooks
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        self.deleteIndexPaths.removeAllObjects()
        self.insertIndexPaths.removeAllObjects()
        for item in updateItems {
            switch item.updateAction {
            case .insert:
                if let indexPath: IndexPath = item.indexPathAfterUpdate {
                    self.insertIndexPaths.add(indexPath)
                }
            case .delete:
            if let indexPath: IndexPath = item.indexPathBeforeUpdate {
                self.deleteIndexPaths.add(indexPath)
            }
            default:
                break
            }
        }
    }
    
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes: UICollectionViewLayoutAttributes = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath) else {
            return nil
        }
        if self.insertIndexPaths.contains(itemIndexPath),
            let targetIndexPath: IndexPath = self.targetIndexPath,
            let targetAttributes: UICollectionViewLayoutAttributes = self.layoutAttributesForItem(at: targetIndexPath) {
            attributes.alpha = 0.0
            attributes.center = targetAttributes.center
        }
        return attributes
    }
    
    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes: UICollectionViewLayoutAttributes = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath) else {
            return nil
        }
        if self.deleteIndexPaths.contains(itemIndexPath),
            let targetIndexPath: IndexPath = self.targetIndexPath,
            let targetAttributes: UICollectionViewLayoutAttributes = self.layoutAttributesForItem(at: targetIndexPath) {
            attributes.alpha = 0.0
            attributes.center = targetAttributes.center
        }
        return attributes
    }
    
    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        self.insertIndexPaths.removeAllObjects()
        self.deleteIndexPaths.removeAllObjects()
    }
}


//MARK: - 测试数据
extension HKCollectionAnimationController {
    func makeData() {
        for index in 0...5 {
            var model = HWTItemModel.init(name: "TopLevel \(index)", isFirstLevel: true)
            var tempArr = [HWTItemModel]()
            for subIndex in 0...max(1, (5 - arc4random() % 5)) {
                let model = HWTItemModel.init(name: "SubLevel \(subIndex)", isFirstLevel: false)
                tempArr.append(model)
            }
            model.children = tempArr
            dataSource.append(model)
        }
        
    }
    
}


//MARK: - HWTItemModel
struct HWTItemModel {
    var name = "";
    var isFirstLevel = true
    var isOpen = false
    var children: [HWTItemModel]?
}

//MARK: - DefineCell
class DefineCell: UICollectionViewCell {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        self.contentView.addSubview(self.nameLab)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.nameLab.frame = self.contentView.bounds
    }
    
    func configOptionCellData(itemMode: HWTItemModel) {
        nameLab.text = itemMode.name
        if itemMode.isFirstLevel {
            nameLab.textColor = UIColor.red
        } else {
            nameLab.textColor = UIColor.black
        }
    }
    
    lazy var nameLab: UILabel = {
        let label = UILabel()
        label.backgroundColor = UIColor.clear
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
}
