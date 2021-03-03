# RxInfinitable
这个很小工程实现了下拉刷新数据，上拉加载更多的功能。针对上拉加载更多，由于UIKit没有提供`UIRefreshControl`，所以我简单的封装了`InfinitableView`。

![screenshot](/Images/screen-record.gif)

## 如何使用
有四个步骤：
1. 添加视图

```
tableView.refreshControl = refreshControl
infinitableView.attach(to: self.tableView)
```

2. 下拉刷新的请求

```
let refreshActivity = ActivityIndicator()
self.refreshing = refreshActivity.asDriver()
let r0 = refreshControl.rx.controlEvent(.valueChanged).asObservable().map { () }
let r1 = r0.startWith(() ).flatMapLatest { [weak self](_) -> Observable<[Int]> in
    let error = NSError(domain: "self.notExsist", code: -1, userInfo: nil)
    guard let self = self else { return .error(error) }
    
    return self.refresh().trackActivity(refreshActivity)
}        
```

3. 上拉加载更多的请求

```
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
```

4. 设置请求的互斥状态。即在刷新时不能再加载更多，反之亦然。

```
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
```
## 最后重要的事情
如果你有任何建议或者问题，请去提issue。我很乐意能继续完善它。
