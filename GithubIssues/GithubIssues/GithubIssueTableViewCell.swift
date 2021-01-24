//
//  GithubIssueTableViewCell.swift
//  GithubIssues
//
//  Created by Saivenkata S on 24/01/21.
//

import UIKit

class GithubIssueTableViewCell: UITableViewCell {
    
    @IBOutlet weak var headerLabel: UILabel!
    
    @IBOutlet weak var bodyLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        headerLabel.numberOfLines = 0
        bodyLabel.numberOfLines = 0
    }
    
}
