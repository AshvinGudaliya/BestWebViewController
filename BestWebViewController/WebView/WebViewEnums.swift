//
//  WebViewEnums.swift
//  BestWebViewController
//
//  Created by Ashvin Gudaliya on 06/10/19.
//  Copyright © 2019 AshvinGudaliya. All rights reserved.
//

import UIKit

public enum WebViewConfiguration {
    
    case url(URL)
    case pullToRefresh
    case bypassedSSLHosts([String])
    case userAgent(String)
    case websiteTitleInNavigationBar
    case leftNavigaionBarItemTypes([BarButtonItemType])
    case rightNavigaionBarItemTypes([BarButtonItemType])
    case doneBarButtonItemPosition(NavigationBarPosition)
    case toolbarItemTypes([BarButtonItemType])
    case disableZoom
    case urlsHandledByApp([String: Any])
    case cookies([HTTPCookie])
    case headers([String: String])
    case tintColor(UIColor)
    case delegate(WebViewControllerDelegate?)
    case scrollViewDelegate(WebViewControllerScrollViewDelegate?)
    case showProgressView(height: CGFloat)
    case progressViewTintColor(UIColor)
    
    static func == (lhs: WebViewConfiguration, rhs: WebViewConfiguration) -> Bool {
        switch (lhs, rhs) {
        case (.url, .url): return true
        default:
            return false
        }
    }
}

public enum BarButtonItemType {
    case back
    case forward
    case reload
    case stop
    case activity
    case done
    case flexibleSpace
}

public enum NavigationBarPosition {
    case none
    case left
    case right
}

@objc public enum NavigationType: Int {
    case linkActivated
    case formSubmitted
    case backForward
    case reload
    case formResubmitted
    case other
}
