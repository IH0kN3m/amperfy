import Foundation
import UIKit

class SettingsVC: UITableViewController {
    
    var appDelegate: AppDelegate!
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var buildNumberLabel: UILabel!
    @IBOutlet weak var serverUrlTF: UITextField!
    @IBOutlet weak var usernameTF: UITextField!
    @IBOutlet weak var backendApiLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        
        versionLabel.text = ""
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            versionLabel.text = version
        }
        buildNumberLabel.text = ""
        if let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            buildNumberLabel.text = buildNumber
        }
        if let loginCredentials = self.appDelegate.storage.getLoginCredentials() {
            serverUrlTF.text = loginCredentials.serverUrl
            usernameTF.text = loginCredentials.username
            backendApiLabel.text = loginCredentials.backendApi.description
        }
    }
    
    @IBAction func deleteSongCachePressed(_ sender: Any) {
        let alert = UIAlertController(title: "Delete song cache", message: "Are you sure to delete all downloaded songs from cache?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.downloadManager.stopAndWait()
            self.appDelegate.persistentLibraryStorage.deleteCompleteSongCache()
            self.appDelegate.persistentLibraryStorage.saveContext()
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
    @IBAction func resetAppPressed(_ sender: Any) {
        let alert = UIAlertController(title: "Reset app data", message: "Are you sure to reset app data?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes", style: .destructive , handler: { _ in
            self.appDelegate.player.stop()
            self.appDelegate.downloadManager.stopAndWait()
            self.appDelegate.backgroundSyncerManager.stopAndWait()
            self.appDelegate.storage.deleteLoginCredentials()
            self.appDelegate.persistentLibraryStorage.cleanStorage()
            self.appDelegate.reinit()
            self.performSegue(withIdentifier: Segues.toLogin.rawValue, sender: nil)
        }))
        alert.addAction(UIAlertAction(title: "No", style: .default , handler: nil))
        alert.pruneNegativeWidthConstraintsToAvoidFalseConstraintWarnings()
        self.present(alert, animated: true)
    }
    
}
