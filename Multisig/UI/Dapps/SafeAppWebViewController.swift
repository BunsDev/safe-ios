//
// Created by Dirk Jäckel on 21.06.22.
// Copyright (c) 2022 Gnosis Ltd. All rights reserved.
//

import Foundation
import WebKit
import UIKit

class SafeAppWebViewController: UIViewController, WKUIDelegate, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
//        print("---->       didReceive message: \(message)")
//        print("---->  didReceive message.name: \(message.name)")
//        print("---->  didReceive message.body: \(message.body)")
//        print("----> didReceive message.world.name: \(message.world.name)")

        handleMessage(message.body as? String)
    }

    var webView: WKWebView!

    private func handleMessage(_ message: String?) {

        if let message = message {
            if message.contains("getSafeInfo") {
                handleGetSafeInfo(message)
            } else {
                print("SafeAppWebViewController | Unknown message: \(message)")
            }
        }
    }

    private func handleGetSafeInfo(_ message: String) {
        print("SafeAppWebViewController | handleGetSafeInfo()")
        print("SafeAppWebViewController | Message: \(message)")

        let decoder = JSONDecoder()
        let jsonData = message.data(using: .utf8)!
        do {
            let result = try decoder.decode(SafeInfoRequestData.self, from: jsonData)
            // {"id":"72a4662487","method":"getSafeInfo","env":{"sdkVersion":"6.2.0"}}

            print ("SafeAppWebViewController |     id: \(result.id!)")
            print ("SafeAppWebViewController | method: \(result.method!)")
            print ("SafeAppWebViewController |    env: \(result.env!)")

            try! sendData(id: result.id!, method: result.method!, address: Safe.getSelected()?.address!)

        } catch {
            print("SafeAppWebViewController | Exception thrown for message: \(message)")
        }

    }

    private func sendData(id: String, method: String, address: String?) {


        print("SafeAppWebViewController | aaddress: \(address)")

        webView.evaluateJavaScript("""
                                   successMessage = JSON.parse('{"id":"\(id)","success":true,"version":"6.2.0","data":{"safeAddress":"\(address!)","chainId":4,"threshold":2,"owners":[]}}');
                                   iframe = document.getElementById('iframe-https://cowswap.exchange'); 
                                   iframe.contentWindow.postMessage(successMessage);
                                   """) { any, error in
            print("SafeAppWebViewController | \(any) error in JS execution: \(error)")
        }
    }

    override func loadView() {
        let webConfiguration = WKWebViewConfiguration()
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        webConfiguration.preferences = preferences
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webConfiguration.userContentController.add(self, name: "message")
        webConfiguration.userContentController.add(self, name: "messageData")

        let source = """
                     window.addEventListener('message', function(e) { 
                       window.webkit.messageHandlers.message.postMessage(JSON.stringify(e));
                       console.log(e)
                     });

                     window.addEventListener('message', function(e) { 
                       window.webkit.messageHandlers.messageData.postMessage(JSON.stringify(e.data));
                     });
                     """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webConfiguration.userContentController.addUserScript(script)

        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

//        let urlString = "https://app.uniswap.org"
        let urlString = "https://cowswap.exchange"

        let myURL = URL(string: urlString)
        let myRequest = URLRequest(url: myURL!)
        webView.loadHTMLString("""
                               <html>
                                    <head>
                                        <meta name="viewport" content="width=device-width,initial-scale=1.0">
                                    </head>
                                    <body>
                                        <iframe height="100%" width="100%" frameborder="0" id="iframe-\(urlString)" src="\(urlString)" title="Safe-App" allow="camera" class="sc-fvpsdx leyeXM">
                                        </iframe>
                                    </body>
                               </html>
                               """, baseURL: myURL)
    }
}

struct SafeInfoRequestData: Codable {
    var id: String?
    var method: String?
    var env: EnvironmentData?
}
struct EnvironmentData: Codable {
    var sdkVersion: String?
}
struct SafeInfoResponseData: Codable  {

    var id: String?
    var method: String
}