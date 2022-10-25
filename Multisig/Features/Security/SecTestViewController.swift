//
//  SecTestViewController.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 25.10.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import UIKit

class SecTestViewController: UIViewController {

    @IBOutlet weak var keyIDValueLabel: UILabel!

    var keyID: String!

    let store = MySecStore()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func createKey() {

    }

    @IBAction func findKey() {

    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
