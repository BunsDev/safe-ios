//
//  BorderedInnerTableCell.swift
//  Multisig
//
//  Created by Dmitry Bespalov on 11.01.22.
//  Copyright © 2022 Gnosis Ltd. All rights reserved.
//

import UIKit

class BorderedInnerTableCell: UITableViewCell, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableHeightConstraint: NSLayoutConstraint!

    var cells: [UITableViewCell] = []
    var onCellTap: (Int) -> Void = { _ in }

    override func awakeFromNib() {
        super.awakeFromNib()
        tableView.layer.borderWidth = 2
        tableView.layer.borderColor = UIColor.gray4.cgColor
        tableView.layer.cornerRadius = 10

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60

        // disable scrolling since we will show the full content
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
    }

    func setCells(_ cells: [UITableViewCell]) {
        self.cells = cells
        tableView.reloadData()

        // adjust the table height to show full content
        tableHeightConstraint.constant = tableView.contentSize.height
        setNeedsUpdateConstraints()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cells.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cells[indexPath.row]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onCellTap(indexPath.row)
    }
}