//
//  Infinitable.swift
//  test
//
//  Created by ihugo on 2021/3/3.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

protocol Infinitable: NSObject {
    var delegate: InfinitableDelegate? { get set }
    var isLoading: Bool { get set }
    var scrollView: UIScrollView? { get set }
    var bag: DisposeBag { get set }
    var indicator: UIActivityIndicatorView { get set }
    var originalContentInset: UIEdgeInsets { get set }
    var isEnabled: Bool { get set }
    
    func attach(to scrollView: UIScrollView)
    func detach()
    func endLoading()
}

extension Infinitable {
    func attach(to scrollView: UIScrollView) {
        guard self.scrollView == nil else { return }
        self.scrollView = scrollView
        scrollView.rx.contentOffset.observe(on:MainScheduler.asyncInstance).subscribe(onNext: { [weak self] (offset) in
            guard let self = self else { return }
            guard self.isEnabled else {
                scrollView.contentInset = self.originalContentInset
                return
            }
            
            let frame = scrollView.frame
            let contentHeight = scrollView.contentSize.height
            guard contentHeight > frame.height else { return }
            if self.indicator.superview == nil {
                self.originalContentInset = scrollView.contentInset
            }
            
            var contentInset = scrollView.contentInset
            let indicatorHeight: CGFloat = 50
            contentInset.bottom = self.originalContentInset.bottom + indicatorHeight
            scrollView.contentInset = contentInset
            scrollView.addSubview(self.indicator)
            self.indicator.center = CGPoint(x: frame.width/2, y: contentHeight + indicatorHeight - self.indicator.frame.height / 2)
            
            let triggerHeight = frame.height * 0.1
            // 避免多次调用`triggerLoading`
            if !self.isLoading, offset.y > contentHeight - triggerHeight - frame.height {
                self.isLoading = true
                self.indicator.startAnimating()
                self.delegate?.triggerLoading(view: self)
            }
            
            self.delegate?.didAttach(view: self)
        }).disposed(by: bag)
    }
    
    func detach() {
        self.scrollView?.contentInset = self.originalContentInset
        self.indicator.removeFromSuperview()
        
        self.delegate?.didDetach(view: self)
        
        self.scrollView = nil
        self.bag = DisposeBag()
    }
    
    func endLoading() {
        self.isLoading = false
        self.indicator.stopAnimating()
        self.scrollView?.contentInset = self.originalContentInset
    }
}

protocol InfinitableDelegate: NSObject {
    func triggerLoading(view: Infinitable)
    func didAttach(view: Infinitable)
    func didDetach(view: Infinitable)
}

extension InfinitableDelegate {
    func triggerLoading(view: Infinitable) {}
    func didAttach(view: Infinitable) {}
    func didDetach(view: Infinitable) {}
}

class InfinitableView: NSObject, Infinitable {
    weak var delegate: InfinitableDelegate? = nil
    
    var isLoading: Bool = false
    
    weak var scrollView: UIScrollView? = nil
    
    var bag: DisposeBag = DisposeBag()
    
    var indicator: UIActivityIndicatorView
    
    var originalContentInset: UIEdgeInsets = .zero
    
    var isEnabled: Bool = true
    
    override init() {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        self.indicator = indicator
        super.init()
    }
}

class InfinitableViewProxy: DelegateProxy<InfinitableView, InfinitableDelegate>, InfinitableDelegate, DelegateProxyType {
    internal lazy var didTriggerLoading = PublishSubject<Void>()
    
    static func registerKnownImplementations() {
        self.register { InfinitableViewProxy(infinitableView: $0) }
    }
    
    static func currentDelegate(for object: InfinitableView) -> InfinitableDelegate? {
        let infinitableView: InfinitableView = castOrFatalError(object)
        return infinitableView.delegate
    }
    
    static func setCurrentDelegate(_ delegate: InfinitableDelegate?, to object: InfinitableView) {
        let infinitableView: InfinitableView = castOrFatalError(object)
        infinitableView.delegate = castOptionalOrFatalError(delegate)
    }
    
    init(infinitableView: InfinitableView) {
           super.init(parentObject: infinitableView, delegateProxy: InfinitableViewProxy.self)
    }
    
    func triggerLoading(view: Infinitable) {
        if let delegate = _forwardToDelegate as? InfinitableDelegate {
            delegate.triggerLoading(view: view)
        }
        didTriggerLoading.onNext(())
    }
}

func castOrFatalError<T>(_ value: Any!) -> T {
    let maybeResult: T? = value as? T
    guard let result = maybeResult else {
        fatalError("Failure converting from \(String(describing: value)) to \(T.self)")
    }
    
    return result
}

func castOptionalOrFatalError<T>(_ value: Any?) -> T? {
    if value == nil {
        return nil
    }
    let v: T = castOrFatalError(value)
    return v
}

extension Reactive where Base: InfinitableView {
    var delegate: DelegateProxy<InfinitableView, InfinitableDelegate> {
        return InfinitableViewProxy.proxy(for: base)
    }
    
    var didTriggerLoading: Observable<Void> {
        return InfinitableViewProxy.proxy(for: base)
            .didTriggerLoading.asObservable()
    }
}
