//
//  ViewController.swift
//  test
//
//  Created by ihugo on 2021/3/3.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    let bag = DisposeBag()
    var datasource = [Int]()
    let subject = PublishSubject<[Int]>()
    let refreshControl = UIRefreshControl()
    let infinitableView = InfinitableView()
    var refreshing: Driver<Bool>!
    var loading: Driver<Bool>!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.refreshControl = refreshControl
        infinitableView.attach(to: self.tableView)
        
        subject.do(afterNext: { [weak self, weak infinitableView] (list) in
            guard let self = self else { return }
            self.tableView.refreshControl?.endRefreshing()
            infinitableView?.endLoading()
            
            if list.count == 20 {
                infinitableView?.attach(to: self.tableView)
            } else if list.count > 60 {
                infinitableView?.detach()
            }
        }).bind(to: tableView.rx.items(cellIdentifier: "TableCell", cellType: TableCell.self)) { index, model, cell in
            cell.label.text = "\(index)"
        }.disposed(by: bag)
        
        // 1. 下拉刷新
        let refreshActivity = ActivityIndicator()
        self.refreshing = refreshActivity.asDriver()
        let r0 = refreshControl.rx.controlEvent(.valueChanged).asObservable().map { () }
        let r1 = r0.startWith(() ).flatMapLatest { [weak self](_) -> Observable<[Int]> in
            let error = NSError(domain: "self.notExsist", code: -1, userInfo: nil)
            guard let self = self else { return .error(error) }
            
            return self.refresh().trackActivity(refreshActivity)
        }
        
        // 2. 上拉加载更多
        let loadActivity = ActivityIndicator()
        self.loading = loadActivity.asDriver()
        let r2 = infinitableView.rx.didTriggerLoading.flatMapLatest { [weak self] (_) -> Observable<[Int]> in
            let error = NSError(domain: "self.notExsist", code: -1, userInfo: nil)
            guard let self = self else { return .error(error) }
            return self.loadMore().trackActivity(loadActivity)
        }.flatMapLatest { [weak self] (list) -> Signal<[Int]> in
            guard let self = self else { return .empty() }
            self.datasource.append(contentsOf: list)
            return .just(self.datasource)
        }
        
        Observable<[Int]>.merge(r1, r2).flatMapLatest ({ [weak self] (list) -> Signal<[Int]> in
            self?.datasource = list
            return .just(list)
        }).bind(to: subject).disposed(by: bag)
        
        // 3. 设置请求的互斥状态。即在刷新时不能再加载更多，反之亦然。
        Driver.combineLatest(self.refreshing, self.loading).drive(onNext: { [weak self] (arg0) in
            guard let self = self else { return }
            let (refreshing, loading) = arg0
            self.infinitableView.isEnabled = !refreshing
            
            if !loading {
                self.tableView.refreshControl = self.refreshControl
            } else {
                self.tableView.refreshControl = nil
            }
        }).disposed(by: bag)
    }
    
    func loadMore() -> Single<[Int]> {
        Observable<[Int]>.create({ (subscriber) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                subscriber.onNext([0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9])
                subscriber.onCompleted()
            }
            return Disposables.create { }
        }).asSingle()
    }
    
    func refresh() -> Single<[Int]> {
        infinitableView.isEnabled = false
        return Observable<[Int]>.create({ (subscriber) -> Disposable in
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                subscriber.onNext([0,1,2,3,4,5,6,7,8,9,0,1,2,3,4,5,6,7,8,9])
                subscriber.onCompleted()
            }
            return Disposables.create { }
        }).asSingle()
    }
}

