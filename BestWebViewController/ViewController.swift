//
//  ViewController.swift
//  BestWebViewController
//
//  Created by Ashvin Gudaliya on 06/10/19.
//  Copyright © 2019 AshvinGudaliya. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let url = URL(string: "https://www.google.com") else {
            return
        }
        
        let webViewController = WebViewController()
        let navigationController = UINavigationController(rootViewController: webViewController)
        
        webViewController.configuration(with:
            .url(url),
            .bypassedSSLHosts([url.host!]),
            .pullToRefresh,
            .userAgent("WebViewController/1.0.0"),
            .websiteTitleInNavigationBar,
            .leftNavigaionBarItemTypes([.reload]),
            .rightNavigaionBarItemTypes([.done]),
            .toolbarItemTypes([.back, .flexibleSpace, .forward, .flexibleSpace , .flexibleSpace, .activity]),
            .showProgressView(height: 3),
            .progressViewTintColor(UIColor.red),
            .tintColor(.brown)
        )
        
        webViewController.navigationItem.title = "Google Website"
        self.present(navigationController, animated: true, completion: nil)
    }
}
