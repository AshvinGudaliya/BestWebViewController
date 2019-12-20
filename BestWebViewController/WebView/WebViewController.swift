//
//  WebViewController.swift
//  BestWebViewController
//
//  Created by Ashvin Gudaliya on 06/10/19.
//  Copyright © 2019 AshvinGudaliya. All rights reserved.
//

import UIKit
import WebKit

let estimatedProgressKeyPath = "estimatedProgress"
let titleKeyPath = "title"
let cookieKey = "Cookie"

open class WebViewController: UIViewController {
    
    var configuration: [WebViewConfiguration] = []
    var url: URL?
    fileprivate var bypassedSSLHosts: [String]?
    fileprivate var userAgent: String?
    fileprivate var disableZoom = false
    fileprivate var pullToRefresh = false
    fileprivate var urlsHandledByApp = [
        "hosts": ["itunes.apple.com"],
        "schemes": ["tel", "mailto", "sms"],
        "_blank": true
        ] as [String : Any]
    
    fileprivate var cookies: [HTTPCookie]? {
        didSet {
            var shouldReload = (cookies != nil && oldValue == nil) || (cookies == nil && oldValue != nil)
            if let cookies = cookies, let oldValue = oldValue, cookies != oldValue {
                shouldReload = true
            }
            if shouldReload, let url = url {
                load(url)
            }
        }
    }
    
    fileprivate var headers: [String: String]? {
        didSet {
            var shouldReload = (headers != nil && oldValue == nil) || (headers == nil && oldValue != nil)
            if let headers = headers, let oldValue = oldValue, headers != oldValue {
                shouldReload = true
            }
            if shouldReload, let url = url {
                load(url)
            }
        }
    }
    
    fileprivate var delegate: WebViewControllerDelegate?
    fileprivate var scrollViewDelegate: WebViewControllerScrollViewDelegate?
    
    fileprivate var progressViewTintColor: UIColor?
    fileprivate var progressViewHeight: CGFloat?
    
    fileprivate var tintColor: UIColor?
    fileprivate var websiteTitleInNavigationBar = true
    fileprivate var doneBarButtonItemPosition: NavigationBarPosition = .right
    fileprivate var leftNavigaionBarItemTypes: [BarButtonItemType] = []
    fileprivate var rightNavigaionBarItemTypes: [BarButtonItemType] = []
    fileprivate var toolbarItemTypes: [BarButtonItemType] = [.back, .forward, .reload, .activity]
    
    fileprivate var webView: WKWebView?
    fileprivate var progressView: UIProgressView?
    fileprivate var refreshControl: UIRefreshControl?
    
    fileprivate var previousNavigationBarState: (tintColor: UIColor, hidden: Bool) = (.black, false)
    fileprivate var previousToolbarState: (tintColor: UIColor, hidden: Bool) = (.black, false)
    
    fileprivate var scrollToRefresh = false
    
    lazy fileprivate var backBarButtonItem: UIBarButtonItem = {
        let bundle = Bundle(for: WebViewController.self)
        return UIBarButtonItem(image: UIImage(named: "Back", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(backDidClick(sender:)))
    }()
    
    lazy fileprivate var forwardBarButtonItem: UIBarButtonItem = {
        let bundle = Bundle(for: WebViewController.self)
        return UIBarButtonItem(image: UIImage(named: "Forward", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(forwardDidClick(sender:)))
    }()
    
    lazy fileprivate var reloadBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(reloadDidClick(sender:)))
    }()
    
    lazy fileprivate var stopBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .stop, target: self, action: #selector(stopDidClick(sender:)))
    }()
    
    lazy fileprivate var activityBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(activityDidClick(sender:)))
    }()
    
    lazy fileprivate var doneBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneDidClick(sender:)))
    }()
    
    lazy fileprivate var flexibleSpaceBarButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }()
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = navigationItem.title ?? url?.absoluteString
        
        if let navigationController = navigationController {
            previousNavigationBarState = (navigationController.navigationBar.tintColor, navigationController.navigationBar.isHidden)
            previousToolbarState = (navigationController.toolbar.tintColor, navigationController.toolbar.isHidden)
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        rollbackState()
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        webView?.removeObserver(self, forKeyPath: estimatedProgressKeyPath)
        webView?.removeObserver(self, forKeyPath: titleKeyPath)
        webView?.scrollView.delegate = nil
    }
    
    func configuration(with configuration: WebViewConfiguration... ) {
        self.configuration = configuration
        
        for config in self.configuration {
            switch config {
            case let .url(url): self.url = url
            case .pullToRefresh: self.pullToRefresh = true
            case let .bypassedSSLHosts(value): self.bypassedSSLHosts = value
            case let .userAgent(value): self.userAgent = value
            case .websiteTitleInNavigationBar: self.websiteTitleInNavigationBar = true
            case let .leftNavigaionBarItemTypes(value): self.leftNavigaionBarItemTypes = value
            case let .rightNavigaionBarItemTypes(value): self.rightNavigaionBarItemTypes = value
            case let .doneBarButtonItemPosition(value): self.doneBarButtonItemPosition = value
            case let .toolbarItemTypes(value): self.toolbarItemTypes = value
            case .disableZoom: self.disableZoom = true
            case let .urlsHandledByApp(value): self.urlsHandledByApp = value
            case let .cookies(value): self.cookies = value
            case let .headers(value): self.headers = value
            case let .tintColor(value): self.tintColor = value
            case let .delegate(value): self.delegate = value
            case let .scrollViewDelegate(value): self.scrollViewDelegate = value
            case let .showProgressView(height): progressViewHeight = height
            case let .progressViewTintColor(color): progressViewTintColor = color
            }
        }
        
        setUpState()
    }
    
    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case estimatedProgressKeyPath?:
            guard let estimatedProgress = webView?.estimatedProgress else {
                return
            }
            progressView?.alpha = 1
            progressView?.setProgress(Float(estimatedProgress), animated: true)
            
            if estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView?.alpha = 0
                }, completion: {
                    finished in
                    self.progressView?.setProgress(0, animated: false)
                })
            }
        case titleKeyPath?:
            if websiteTitleInNavigationBar || URL(string: navigationItem.title ?? "")?.appendingPathComponent("") == url?.appendingPathComponent("") {
                navigationItem.title = webView?.title
            }
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// MARK: - Public Methods
public extension WebViewController {
    func load(_ url: URL) {
        guard let webView = webView else {
            return
        }
        let request = createRequest(url: url)
        DispatchQueue.main.async {
            webView.load(request)
        }
    }
    
    func goBackToFirstPage() {
        if let firstPageItem = webView?.backForwardList.backList.first {
            webView?.go(to: firstPageItem)
        }
    }
    
    func scrollToTop(animated: Bool, refresh: Bool = false) {
        var offsetY: CGFloat = 0
        if let navigationController = navigationController {
            offsetY -= navigationController.navigationBar.frame.size.height + UIApplication.shared.statusBarFrame.height
        }
        if refresh, let refreshControl = refreshControl {
            offsetY -= refreshControl.frame.size.height
        }
        
        scrollToRefresh = refresh
        webView?.scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
    }
    
    func isScrollToTop() -> Bool {
        guard let scrollView = webView?.scrollView else {
            return false
        }
        return scrollView.contentOffset.y <= CGFloat(0)
    }
}

// MARK: - Fileprivate Methods
fileprivate extension WebViewController {
    var availableCookies: [HTTPCookie]? {
        return cookies?.filter {
            cookie in
            var result = true
            if let host = url?.host, !cookie.domain.hasSuffix(host) {
                result = false
            }
            if cookie.isSecure && url?.scheme != "https" {
                result = false
            }
            
            return result
        }
    }
    
    func createRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // Set up headers
        if let headers = headers {
            for (field, value) in headers {
                request.addValue(value, forHTTPHeaderField: field)
            }
        }
        
        // Set up Cookies
        if let cookies = availableCookies, let value = HTTPCookie.requestHeaderFields(with: cookies)[cookieKey] {
            request.addValue(value, forHTTPHeaderField: cookieKey)
        }
        
        return request
    }
    
    func setUpState() {
        setUpProgressView()
        setUpWebView()
        addBarButtonItems()
        
        if pullToRefresh {
            setUpRefreshControl()
        }
        
        if let userAgent = userAgent {
            webView?.evaluateJavaScript("navigator.userAgent") { (result: Any?, error: Error?) in
                if let originalUserAgent = result as? String {
                    self.webView?.customUserAgent = [originalUserAgent, userAgent].joined(separator: " ")
                }
                else {
                    self.webView?.customUserAgent = userAgent
                }
            }
        }
        
        if let url = url {
            load(url)
        }
        else {
            fatalError("[WebViewController][Error] NULL URL")
        }
        
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.setToolbarHidden(toolbarItemTypes.count == 0, animated: true)
        
        if let tintColor = tintColor {
            navigationController?.navigationBar.tintColor = tintColor
            navigationController?.toolbar.tintColor = tintColor
        }
    }
    
    func setUpWebView() {
        let webConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.scrollView.delegate = self
        
        webView.allowsBackForwardNavigationGestures = true
        webView.isMultipleTouchEnabled = true
        
        webView.addObserver(self, forKeyPath: estimatedProgressKeyPath, options: .new, context: nil)
        webView.addObserver(self, forKeyPath: titleKeyPath, options: .new, context: nil)
        
        view.addSubview(webView)
        self.webView = webView
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ])
    }
    
    func setUpProgressView() {
        if let height = progressViewHeight {
            let progressView = UIProgressView(progressViewStyle: .default)
            progressView.trackTintColor = UIColor(white: 1, alpha: 0)
            self.view.addSubview(progressView)
            progressView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                progressView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
                progressView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                progressView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                progressView.heightAnchor.constraint(equalToConstant: height)
                ])
            self.progressView = progressView
            if let progressViewTintColor = progressViewTintColor {
                progressView.progressTintColor = progressViewTintColor
            }
        }
    }
    
    func setUpRefreshControl() {
        guard refreshControl == nil else {
            return
        }
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWebView(sender:)), for: UIControl.Event.valueChanged)
        webView?.scrollView.addSubview(refreshControl)
        webView?.scrollView.bounces = true
        self.refreshControl = refreshControl
    }
    
    func addBarButtonItems() {
        let barButtonItems: [BarButtonItemType: UIBarButtonItem] = [
            .back: backBarButtonItem,
            .forward: forwardBarButtonItem,
            .reload: reloadBarButtonItem,
            .stop: stopBarButtonItem,
            .activity: activityBarButtonItem,
            .done: doneBarButtonItem,
            .flexibleSpace: flexibleSpaceBarButtonItem
        ]
        
        if presentingViewController != nil {
            switch doneBarButtonItemPosition {
            case .left:
                if !leftNavigaionBarItemTypes.contains(.done) {
                    leftNavigaionBarItemTypes.insert(.done, at: 0)
                }
            case .right:
                if !rightNavigaionBarItemTypes.contains(.done) {
                    rightNavigaionBarItemTypes.insert(.done, at: 0)
                }
            case .none:
                break
            }
        }
        
        navigationItem.leftBarButtonItems = navigationItem.leftBarButtonItems ?? [] + leftNavigaionBarItemTypes.map {
            barButtonItemType in
            if let barButtonItem = barButtonItems[barButtonItemType] {
                return barButtonItem
            }
            return UIBarButtonItem()
        }
        
        navigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems ?? [] + rightNavigaionBarItemTypes.map {
            barButtonItemType in
            if let barButtonItem = barButtonItems[barButtonItemType] {
                return barButtonItem
            }
            return UIBarButtonItem()
        }
        
        setToolbarItems(toolbarItemTypes.map { barButtonItemType -> UIBarButtonItem in
            if let barButtonItem = barButtonItems[barButtonItemType] {
                return barButtonItem
            }
            return UIBarButtonItem()
        }, animated: true)
    }
    
    func updateBarButtonItems() {
        backBarButtonItem.isEnabled = webView?.canGoBack ?? false
        forwardBarButtonItem.isEnabled = webView?.canGoForward ?? false
        
        let updateReloadBarButtonItem: (UIBarButtonItem, Bool) -> UIBarButtonItem = {
            [unowned self] barButtonItem, isLoading in
            switch barButtonItem {
            case self.reloadBarButtonItem:
                fallthrough
            case self.stopBarButtonItem:
                return isLoading ? self.stopBarButtonItem : self.reloadBarButtonItem
            default:
                break
            }
            return barButtonItem
        }
        
        let isLoading = webView?.isLoading ?? false
        toolbarItems = toolbarItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
        
        navigationItem.leftBarButtonItems = navigationItem.leftBarButtonItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
        
        navigationItem.rightBarButtonItems = navigationItem.rightBarButtonItems?.map {
            barButtonItem -> UIBarButtonItem in
            return updateReloadBarButtonItem(barButtonItem, isLoading)
        }
    }
    
    func rollbackState() {
        progressView?.removeFromSuperview()
        
        navigationController?.navigationBar.tintColor = previousNavigationBarState.tintColor
        navigationController?.toolbar.tintColor = previousToolbarState.tintColor
        
        navigationController?.setToolbarHidden(previousToolbarState.hidden, animated: true)
        navigationController?.setNavigationBarHidden(previousNavigationBarState.hidden, animated: true)
    }
    
    func checkRequestCookies(_ request: URLRequest, cookies: [HTTPCookie]) -> Bool {
        if cookies.count <= 0 {
            return true
        }
        guard let headerFields = request.allHTTPHeaderFields, let cookieString = headerFields[cookieKey] else {
            return false
        }
        
        let requestCookies = cookieString.components(separatedBy: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "=", maxSplits: 1).map(String.init)
        }
        
        var valid = false
        for cookie in cookies {
            valid = requestCookies.filter {
                $0[0] == cookie.name && $0[1] == cookie.value
                }.count > 0
            if !valid {
                break
            }
        }
        return valid
    }
    
    func openURLWithApp(_ url: URL) -> Bool {
        let application = UIApplication.shared
        return application.canOpenURL(url)
    }
    
    func handleURLWithApp(_ url: URL, targetFrame: WKFrameInfo?) -> Bool {
        let hosts = urlsHandledByApp["hosts"] as? [String]
        let schemes = urlsHandledByApp["schemes"] as? [String]
        let blank = urlsHandledByApp["_blank"] as? Bool
        
        var tryToOpenURLWithApp = false
        if let host = url.host, hosts?.contains(host) ?? false {
            tryToOpenURLWithApp = true
        }
        if let scheme = url.scheme, schemes?.contains(scheme) ?? false {
            tryToOpenURLWithApp = true
        }
        if blank ?? false && targetFrame == nil {
            tryToOpenURLWithApp = true
        }
        
        return tryToOpenURLWithApp ? openURLWithApp(url) : false
    }
}

// MARK: - WKUIDelegate
extension WebViewController: WKUIDelegate {
    
}

// MARK: - WKNavigationDelegate
extension WebViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateBarButtonItems()
        if let url = webView.url {
            delegate?.webViewController?(self, didStart: url)
        }
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateBarButtonItems()
        if let refreshControl = refreshControl {
            refreshControl.endRefreshing()
        }
        
        if let url = webView.url {
            delegate?.webViewController?(self, didFinish: url)
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateBarButtonItems()
        if let refreshControl = refreshControl {
            refreshControl.endRefreshing()
        }
        
        if let url = webView.url {
            delegate?.webViewController?(self, didFail: url, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateBarButtonItems()
        if let refreshControl = refreshControl {
            refreshControl.endRefreshing()
        }
        
        if let url = webView.url {
            delegate?.webViewController?(self, didFail: url, withError: error)
        }
    }
    
    public func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if let bypassedSSLHosts = bypassedSSLHosts, bypassedSSLHosts.contains(challenge.protectionSpace.host) {
            let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var actionPolicy: WKNavigationActionPolicy = .allow
        defer {
            decisionHandler(actionPolicy)
        }
        
        guard let url = navigationAction.request.url, !url.isFileURL else { return }
        
        if let targetFrame = navigationAction.targetFrame, !targetFrame.isMainFrame { return }
        
        if handleURLWithApp(url, targetFrame: navigationAction.targetFrame) {
            actionPolicy = .cancel
            return
        }
        
        if let navigationType = NavigationType(rawValue: navigationAction.navigationType.rawValue), let result = delegate?.webViewController?(self, decidePolicy: url, navigationType: navigationType) {
            actionPolicy = result ? .allow : .cancel
            if actionPolicy == .cancel {
                return
            }
        }
        
        switch navigationAction.navigationType {
        case .formSubmitted:
            fallthrough
        case .linkActivated:
            if let fragment = url.fragment {
                let removedFramgnetURL = URL(string: url.absoluteString.replacingOccurrences(of: "#\(fragment)", with: ""))
                if removedFramgnetURL == self.url {
                    fallthrough
                }
            }
        default:
            // Ensure all available cookies are set in the navigation request
            if url.host == self.url?.host, let cookies = availableCookies, !checkRequestCookies(navigationAction.request, cookies: cookies) {
                load(url)
                actionPolicy = .cancel
            }
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        var responsePolicy: WKNavigationResponsePolicy = .allow
        defer {
            decisionHandler(responsePolicy)
        }
        guard let url = navigationResponse.response.url, !url.isFileURL else {
            return
        }
        
        if let result = delegate?.webViewController?(self, decidePolicy: url, response: navigationResponse.response) {
            responsePolicy = result ? .allow : .cancel
        }
    }
}

extension WebViewController: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return disableZoom ? nil : scrollView.subviews[0]
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if scrollToRefresh, let refreshControl = refreshControl {
            refreshWebView(sender: refreshControl)
        }
        scrollToRefresh = false
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollViewDelegate?.scrollViewDidScroll?(scrollView)
    }
}

// MARK: - @objc
@objc extension WebViewController {
    func backDidClick(sender: AnyObject) {
        webView?.goBack()
    }
    
    func forwardDidClick(sender: AnyObject) {
        webView?.goForward()
    }
    
    func reloadDidClick(sender: AnyObject) {
        webView?.stopLoading()
        if webView?.url != nil {
            webView?.reload()
        }
        else if let url = url {
            load(url)
        }
    }
    
    func stopDidClick(sender: AnyObject) {
        webView?.stopLoading()
    }
    
    func activityDidClick(sender: AnyObject) {
        guard let url = url else {
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }
    
    func doneDidClick(sender: AnyObject) {
        var canDismiss = true
        if let url = url {
            canDismiss = delegate?.webViewController?(self, canDismiss: url) ?? true
        }
        if canDismiss {
            dismiss(animated: true, completion: nil)
        }
    }
    
    func refreshWebView(sender: UIRefreshControl) {
        let isLoading = webView?.isLoading ?? false
        if !isLoading {
            sender.beginRefreshing()
            reloadDidClick(sender: sender)
        }
    }
}
