//
//  WebViewControllerDelegate.swift
//  BestWebViewController
//
//  Created by Ashvin Gudaliya on 06/10/19.
//  Copyright © 2019 AshvinGudaliya. All rights reserved.
//

import UIKit
import WebKit

@objc public protocol WebViewControllerDelegate {
    @objc optional func webViewController(_ controller: WebViewController, canDismiss url: URL) -> Bool
    @objc optional func webViewController(_ controller: WebViewController, didStart url: URL)
    @objc optional func webViewController(_ controller: WebViewController, didFinish url: URL)
    @objc optional func webViewController(_ controller: WebViewController, didFail url: URL, withError error: Error)
    @objc optional func webViewController(_ controller: WebViewController, decidePolicy url: URL, navigationType: NavigationType) -> Bool
    @objc optional func webViewController(_ controller: WebViewController, decidePolicy url: URL, response: URLResponse) -> Bool
}

@objc public protocol WebViewControllerScrollViewDelegate {
    @objc optional func scrollViewDidScroll(_ scrollView: UIScrollView)
}

