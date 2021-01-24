

import UIKit

enum ControllerType {
    case IssueList
    case CommentList
}

class GitHubIssuesListViewController: UIViewController {

    @IBOutlet weak var gitHubIssuesTableView: UITableView!
    var gitHubIssuesDataSource: [[String: Any]] = []
    var controllerType: ControllerType = .IssueList
    var commentsUrl = ""
    let perPage = 50
    var currentPage = 1
    var lastPageReached = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpTableViewProperties()
        callGithubIssuesAPI(shouldCallCommentsAPI: controllerType == .CommentList)
        if controllerType == .CommentList {
            navigationItem.title = "Comments"
        }
    }
    
    func setUpTableViewProperties() {
        gitHubIssuesTableView.delegate = self
        gitHubIssuesTableView.dataSource = self
        gitHubIssuesTableView.register(UINib(nibName: "GithubIssueTableViewCell", bundle: nil), forCellReuseIdentifier: "GithubIssueTableViewCell")
    }
    
    func callGithubIssuesAPI(shouldCallCommentsAPI: Bool = false) {
        if shouldCallCommentsAPI == false {
            let cacheData = getDataFromCache()
            if let lastSavedDate = UserDefaults.standard.value(forKey: "LastSavedAt") as? Date, abs(lastSavedDate.timeIntervalSince(Date())) < 86400 {
                if UserDefaults.standard.bool(forKey: "CompleteDataSaved") {
                    gitHubIssuesDataSource = cacheData
                    gitHubIssuesTableView.reloadData()
                    return
                } else if currentPage * perPage <= cacheData.count {
                    gitHubIssuesDataSource = cacheData
                    gitHubIssuesTableView.reloadData()
                    return
                }
            } else {
                UserDefaults.standard.set(false, forKey: "CompleteDataSaved")
            }
        }
        var urlString = ""
        urlString = shouldCallCommentsAPI ? commentsUrl + "?per_page=\(perPage)&page=\(currentPage)" : "https://api.github.com/repos/firebase/firebase-ios-sdk/issues?sort=updated&per_page=\(perPage)&page=\(currentPage)&state=open"
        guard let firebaseIssuesURL = URL(string: urlString) else { return }
        let task = URLSession.shared.dataTask(with: firebaseIssuesURL) { [self] (data, response, error) in
            self.gitHubIssuesTableView.removeLoaderFromFooter()
            do {
                let dataArray = try JSONSerialization.jsonObject(with: data!, options: .mutableLeaves) as? [[String: Any]]
                self.gitHubIssuesDataSource.append(contentsOf: dataArray ?? [])
                if controllerType == .IssueList {
                    self.saveDataToCache()
                }
                if dataArray?.count ?? 1000 < self.perPage {
                    self.lastPageReached = true
                    if controllerType == .IssueList {
                        UserDefaults.standard.set(true, forKey: "CompleteDataSaved")
                    }
                }
                DispatchQueue.main.async {
                    self.gitHubIssuesTableView.reloadData()
                }
            } catch {
                print(error)
            }
        }
        task.resume()
    }
    
    func saveDataToCache() {
        UserDefaults.standard.set(Date(), forKey: "LastSavedAt")
        guard let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { fatalError("Document directory not found") }
        let data = try? JSONSerialization.data(withJSONObject: self.gitHubIssuesDataSource, options: .fragmentsAllowed)
        try? data?.write(to: documentURL.appendingPathComponent("issues.json"), options: [])
    }
    
    func getDataFromCache() -> [[String: Any]] {
        guard let documentURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { fatalError("Document directory not found") }
        let data = try? Data(contentsOf: documentURL.appendingPathComponent("issues.json"))
        guard let validData = data else { return []  }
        let dataSource = try? JSONSerialization.jsonObject(with: validData, options: .allowFragments) as? [[String: Any]]
        return dataSource ?? []
    }

}

extension GitHubIssuesListViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return gitHubIssuesDataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "GithubIssueTableViewCell", for: indexPath) as? GithubIssueTableViewCell else { return UITableViewCell() }
        cell.selectionStyle = .none
        if controllerType == .IssueList {
            cell.headerLabel.text = gitHubIssuesDataSource[indexPath.row]["title"] as? String
            cell.bodyLabel.text = "\((gitHubIssuesDataSource[indexPath.row]["body"] as? String)?.prefix(140) ?? "")"
        } else {
            cell.headerLabel.text = (gitHubIssuesDataSource[indexPath.row]["user"] as? [String: Any])?["login"] as? String
            cell.bodyLabel.text = gitHubIssuesDataSource[indexPath.row]["body"] as? String
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if controllerType == .IssueList {
            let commentsCount = gitHubIssuesDataSource[indexPath.row]["comments"] as? Int
            if commentsCount == 0 {
                let alert = UIAlertController(title: "No comments available for issue!", message: "", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
                    return
                }))
                present(alert, animated: true)
            } else {
                guard let viewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "GitHubIssuesListViewController") as? GitHubIssuesListViewController else { return }
                viewController.controllerType = .CommentList
                viewController.commentsUrl = gitHubIssuesDataSource[indexPath.row]["comments_url"] as? String ?? ""
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == gitHubIssuesDataSource.count - 1 {
            if lastPageReached == false, UserDefaults.standard.bool(forKey: "CompleteDataSaved") == false {
                currentPage += 1
                callGithubIssuesAPI(shouldCallCommentsAPI: controllerType == .CommentList)
                tableView.addLoaderToFooter()
            }
        }
    }
    
}

extension UITableView {
    func addLoaderToFooter(message: String = "Fetching results...") {
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width, height: 40))
        let loader = UIActivityIndicatorView(frame: CGRect(x: 16, y: 8, width: 30, height: 30))
        loader.startAnimating()
        let messageLabel = UILabel(frame: CGRect(x: loader.frame.maxX + 10, y: 16, width: 200, height: 20))
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.text = message
        footerView.addSubview(loader)
        footerView.addSubview(messageLabel)
        tableFooterView = footerView
    }
    
    func removeLoaderFromFooter() {
        DispatchQueue.main.async {
            self.tableFooterView = nil
        }
    }
}

