import UIKit
import RealmSwift

class RideListController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var directionControl: UISegmentedControl!
    @IBOutlet weak var filterLabel: UILabel!
    @IBOutlet weak var filterView: UIView!
    @IBOutlet weak var filterViewHeight: NSLayoutConstraint!
    @IBOutlet weak var filterViewHeightZero: NSLayoutConstraint!
    @IBInspectable var emptyMessage: String?
    @IBInspectable var historyTable = false
    
    let RideListDefaultEmptyMessage = "Nenhuma carona\nencontrada."
    let RideListDefaultLoadingMessage = "Carregando..."
    let RideListDefaultErrorMessage = "Não foi possível\ncarregar as caronas."
    
    let RideListMessageFontSize: CGFloat = 25.0
    
    var ridesDirectionGoing = true
    var hidesDirectionControl = false
    var filterIsEnabled = false
    
    var refreshControl: UIRefreshControl?

    var rides = [Ride]() {
        didSet {
            self.updateFilteredRides()
        }
    }
    var filteredRides = [Ride]()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.view = Bundle.main.loadNibNamed(String(describing: RideListController.self), owner: self, options: nil)?.first as! UIView
        
        if self.responds(to: #selector(refreshTable)) {
            refreshControl = UIRefreshControl()
            refreshControl?.tintColor = UIColor.init(white: 0.9, alpha: 1.0)
            refreshControl?.addTarget(self, action: #selector(refreshTable), for: .valueChanged)
            self.tableView.addSubview(refreshControl!)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 11.0, *) {
            // Create constraint between filterView and safe area layout guide
            let safeArea = self.view.safeAreaLayoutGuide;
            filterView.topAnchor.constraint(equalTo: safeArea.topAnchor).isActive = true
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        let cellNib = UINib.init(nibName: String(describing: RideCell.self), bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "Ride Cell")
        
        if hidesDirectionControl {
            DispatchQueue.main.async {
                self.directionControl.removeFromSuperview()
            }
        } else {
            // Configure direction titles according to institution
            directionControl.setTitle(UserService.Institution.goingLabel, forSegmentAt: 0)
            directionControl.setTitle(UserService.Institution.leavingLabel, forSegmentAt: 1)
        }
        adjustTableView()
        
        tableView.rowHeight = 85.0
        tableView.backgroundView = loadingLabel
        
        if historyTable {
            tableView.allowsSelection = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        adjustFilterView(animated: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        adjustTableView()
    }
    
    @objc func refreshTable() {
    }
    
    func adjustFilterView(animated: Bool) {
        if hidesDirectionControl {
            view.layoutIfNeeded()
            filterViewHeightZero.isActive = true
            return
        }
        
        if filterIsEnabled {
            view.layoutIfNeeded()
            filterViewHeightZero.isActive = false
            filterView.layer.masksToBounds = false
        } else {
            filterView.layer.masksToBounds = true
            if animated {
                filterViewHeightZero.isActive = true
                UIView.animate(withDuration: 0.2, animations: {
                    self.view.layoutIfNeeded()
                })
            } else {
                view.layoutIfNeeded()
                filterViewHeightZero.isActive = true
            }
        }
    }
    
    func adjustTableView() {
        if hidesDirectionControl {
            return
        }
        
        var defaultTopInset: CGFloat = 64.0
        var defaultBottomInset: CGFloat = 49.0
        if #available(iOS 11.0, *) {
            defaultTopInset = 0.0
            defaultBottomInset = 0.0
        }
        
        guard let navigationBarHeight = self.navigationController?.navigationBar.frame.size.height else {
            return
        }
        if filterIsEnabled {
            let filterViewHeight = self.filterViewHeight.constant
            tableView.scrollIndicatorInsets = UIEdgeInsetsMake(defaultTopInset + filterViewHeight, 0.0, defaultBottomInset, 0.0)
            tableView.contentInset = UIEdgeInsetsMake(defaultTopInset + navigationBarHeight + filterViewHeight, 0.0, defaultBottomInset, 0.0)
        } else {
            tableView.scrollIndicatorInsets = UIEdgeInsetsMake(defaultTopInset, 0.0, defaultBottomInset, 0.0)
            tableView.contentInset = UIEdgeInsetsMake(defaultTopInset + navigationBarHeight, 0.0, defaultBottomInset, 0.0)
        }
    }
    
    func updateFilteredRides() {
        tableView.backgroundView = rides.isEmpty ? emptyTableLabel : nil
        
        if hidesDirectionControl {
            filteredRides = rides
        } else {
            filteredRides = rides.filter({ $0.going == ridesDirectionGoing })
        }
    }
    
    func loadingFailed(withError error: NSError, checkFilteredRides: Bool = true) {
        if checkFilteredRides && filteredRides.isEmpty {
            tableView.backgroundView = errorLabel
        }
        
        NSLog("%@ failed to load rides: %@", String(describing: type(of: self)), error.localizedDescription)
        
        guard self.isVisible() else {
            return
        }
        
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                CaronaeMessagesNotification.instance.showError(withText: "Sem conexão com a internet")
                return
            case NSURLErrorTimedOut,
                 NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost:
                CaronaeMessagesNotification.instance.showError(withText: "Sem conexão com o Caronaê")
                return
            default:
                break
            }
        }
        
        let errorAlertTitle = "Algo deu errado"
        let errorAlertMessage = String(format: "Não foi possível carregar as caronas. Por favor, tente novamente. (%@)", error.localizedDescription)
        CaronaeAlertController.presentOkAlert(withTitle: errorAlertTitle, message: errorAlertMessage)
    }
    
    
    // MARK: Table methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRides.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Ride Cell", for: indexPath) as! RideCell
        
        if historyTable {
            cell.configureHistoryCell(with: filteredRides[indexPath.row])
        } else {
            cell.configureCell(with: filteredRides[indexPath.row])
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if !historyTable {
            let ride = filteredRides[indexPath.row]
            let rideVC = RideViewController.instance(for: ride)
            navigationController?.show(rideVC, sender: self)
        }
    }
    
    
    // MARK: IBActions
    
    @IBAction func didChangeDirection(_ sender: UISegmentedControl) {
        ridesDirectionGoing = sender.selectedSegmentIndex == 0
        updateFilteredRides()
        tableView.reloadData()
    }
    
    @IBAction func didTapFilterView(_ sender: Any) {
        performSegue(withIdentifier: "FilterRide", sender: self)
    }
    
    @IBAction func didTapClearFilterButton(_ sender: UIButton!) {
        filterIsEnabled = false
        adjustFilterView(animated: true)
    }
    
    
    // MARK: Extra views
    
    // Background view when the table is empty
    lazy var emptyTableLabel: UILabel = {
        let emptyTableLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        emptyTableLabel.text = self.emptyMessage ?? self.RideListDefaultEmptyMessage
        emptyTableLabel.textColor = .gray
        emptyTableLabel.numberOfLines = 0
        emptyTableLabel.textAlignment = .center
        emptyTableLabel.font = UIFont.systemFont(ofSize: self.RideListMessageFontSize, weight: .ultraLight)
        emptyTableLabel.sizeToFit()
        return emptyTableLabel
    }()
    
    // Background view when an error occurs
    lazy var errorLabel: UILabel = {
        let errorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        errorLabel.text = self.RideListDefaultErrorMessage
        errorLabel.textColor = .gray
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = UIFont.systemFont(ofSize: self.RideListMessageFontSize, weight: .ultraLight)
        errorLabel.sizeToFit()
        return errorLabel
    }()

    // Background view when the table is loading
    lazy var loadingLabel: UILabel = {
        let loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        loadingLabel.text = self.RideListDefaultLoadingMessage
        loadingLabel.textColor = .gray
        loadingLabel.numberOfLines = 0
        loadingLabel.textAlignment = .center
        loadingLabel.font = UIFont.systemFont(ofSize: self.RideListMessageFontSize, weight: .ultraLight)
        loadingLabel.sizeToFit()
        return loadingLabel
    }()
    
}
