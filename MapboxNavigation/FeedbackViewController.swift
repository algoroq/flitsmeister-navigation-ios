import UIKit
import MapboxCoreNavigation
import AVFoundation

extension FeedbackViewController: UIViewControllerTransitioningDelegate {
    @objc public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        abortAutodismiss()
        return DismissAnimator()
    }
    
    @objc public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return PresentAnimator()
    }
    
    @objc public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return interactor.hasStarted ? interactor : nil
    }
}

/**
 A view controller containing a grid of buttons the user can use to denote an issue their current navigation experience.
 */
@objc(MBFeedbackViewController)
public class FeedbackViewController: UIViewController, DismissDraggable, UIGestureRecognizerDelegate {
    
    var sendFeedbackHandler: ((FeedbackItem) -> Void)?
    var dismissFeedbackHandler: (() -> Void)?
    var activeFeedbackItem: FeedbackItem?
    
    static let sceneTitle = NSLocalizedString("FEEDBACK_TITLE", value: "Report Problem", comment: "Title of view controller for sending feedback")
    static let cellReuseIdentifier = "collectionViewCellId"
    static let autoDismissInterval: TimeInterval = 10
    static let verticalCellPadding: CGFloat = 20.0
    
    let interactor = Interactor()
    
    /**
     The feedback items that are visible and selectable by the user.
     */
    public var sections: [FeedbackItem] = [.turnNotAllowed, .closure, .reportTraffic, .confusingInstructions, .generalMapError, .badRoute]
    
    lazy var collectionView: UICollectionView = {
        let view: UICollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.delegate = self
        view.dataSource = self
        view.register(FeedbackCollectionViewCell.self, forCellWithReuseIdentifier: FeedbackCollectionViewCell.defaultIdentifier)
        return view
    }()
    
    lazy var reportIssueLabel: UILabel = {
        let label: UILabel = .forAutoLayout()
        label.textAlignment = .center
        label.text = FeedbackViewController.sceneTitle
        return label
    }()
    
    lazy var flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0.0
        layout.minimumLineSpacing = 0.0
        return layout
    }()
    
    lazy var progressBar: ProgressBar = .forAutoLayout()
    
    var draggableHeight: CGFloat {
        // V:|-0-recordingAudioLabel.height-collectionView.height-progressBar.height-0-|
        let numberOfRows = collectionView.numberOfRows(using: self)
        let padding = (flowLayout.sectionInset.top + flowLayout.sectionInset.bottom) * CGFloat(numberOfRows)
        let indexPath = IndexPath(row: 0, section: 0)
        let collectionViewHeight = collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: indexPath).height * CGFloat(numberOfRows) + padding + view.safeArea.bottom
        let fullHeight = reportIssueLabel.bounds.height+collectionViewHeight+progressBar.bounds.height
        return fullHeight
    }
    
    /**
     The events manager used to send feedback events.
     */
    public var eventsManager: EventsManager
    
    /**
     Initialize a new FeedbackViewController from an `EventsManager`.
     */
    @objc public init(eventsManager: EventsManager) {
        self.eventsManager = eventsManager
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    public override func encode(with aCoder: NSCoder) {
        aCoder.encode(eventsManager, forKey: "EventsManager")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        eventsManager = aDecoder.decodeObject(of: [EventsManager.self], forKey: "EventsManager") as? EventsManager ?? EventsManager(accessToken: nil)
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        view.layoutIfNeeded()
        transitioningDelegate = self
        view.backgroundColor = .white
        progressBar.barColor = #colorLiteral(red: 0.9347146749, green: 0.5047877431, blue: 0.1419634521, alpha: 1)
        enableDraggableDismiss()
        
        let uuid = eventsManager.recordFeedback()
        sendFeedbackHandler = defaultSendFeedbackHandler(uuid: uuid)
        dismissFeedbackHandler = defaultDismissFeedbackHandler(uuid: uuid)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        progressBar.progress = 1
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: FeedbackViewController.autoDismissInterval) {
            self.progressBar.progress = 0
        }
        
        enableAutoDismiss()
    }
    
    override public func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        
        // Dismiss the feedback view when switching between landscape and portrait mode.
        if traitCollection.verticalSizeClass != newCollection.verticalSizeClass {
            dismissFeedback()
        }
    }
    
    func enableAutoDismiss() {
        abortAutodismiss()
        perform(#selector(dismissFeedback), with: nil, afterDelay: FeedbackViewController.autoDismissInterval)
    }
    
    func presentError(_ message: String) {
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Cancel", style: .cancel) { (action) in
            controller.dismiss(animated: true, completion: nil)
        }
        
        controller.addAction(action)
        present(controller, animated: true, completion: nil)
    }
    
    func abortAutodismiss() {
        progressBar.progress = 0
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(dismissFeedback), object: nil)
    }
    
    /**
     Instantly dismisses the FeedbackViewController if it is currently presented.
     */
    @objc public func dismissFeedback() {
        abortAutodismiss()
        dismissFeedbackHandler?()
    }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Only respond to touches outside/behind the view
        let isDescendant = touch.view?.isDescendant(of: view) ?? true
        return !isDescendant
    }
    
    @objc func handleDismissTap(sender: UITapGestureRecognizer) {
        dismissFeedback()
    }
    
    private func setupViews() {
        [reportIssueLabel, collectionView, progressBar].forEach(view.addSubview(_:))
    }
    
    private func setupConstraints() {
        let labelTop = reportIssueLabel.topAnchor.constraint(equalTo: view.topAnchor)
        let labelHeight = reportIssueLabel.heightAnchor.constraint(equalToConstant: 30.0)
        let labelLeading = reportIssueLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let labelTrailing = reportIssueLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let collectionLabelSpacing = collectionView.topAnchor.constraint(equalTo: reportIssueLabel.bottomAnchor)
        let collectionLeading = collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        let collectionTrailing = collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let collectionBarSpacing = collectionView.bottomAnchor.constraint(equalTo: progressBar.topAnchor)
        
        let constraints = [labelTop, labelHeight, labelLeading, labelTrailing,
                           collectionLabelSpacing, collectionLeading, collectionTrailing, collectionBarSpacing]
        
        NSLayoutConstraint.activate(constraints)
        
        progressBar.heightAnchor.constraint(equalToConstant: 6.0).isActive = true
        progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        progressBar.bottomAnchor.constraint(equalTo: view.safeBottomAnchor).isActive = true
    }
    
    func defaultSendFeedbackHandler(source: FeedbackSource = .user, uuid: UUID) -> (FeedbackItem) -> Void {
        return { [weak self] (item) in
            guard let strongSelf = self else { return }
            
            // todo, can this be moved as a delegate on this view controller?
            //strongSelf.delegate?.mapViewController(strongSelf, didSendFeedbackAssigned: uuid, feedbackType: item.feedbackType)
            strongSelf.eventsManager.updateFeedback(uuid: uuid, type: item.feedbackType, source: source, description: nil)
            
            guard let parent = strongSelf.presentingViewController else {
                strongSelf.dismiss(animated: true)
                return
            }
            
            strongSelf.dismiss(animated: true) {
                DialogViewController().present(on: parent)
            }
        }
    }
    
    func defaultDismissFeedbackHandler(uuid: UUID) -> (() -> Void) {
        return { [weak self ] in
            guard let strongSelf = self else { return }
            
            // todo, can this be moved as a delegate on this view controller?
            // strongSelf.delegate?.mapViewControllerDidCancelFeedback(strongSelf)
            strongSelf.eventsManager.cancelFeedback(uuid: uuid)
            strongSelf.dismiss(animated: true, completion: nil)
        }
    }
}

extension FeedbackViewController: UICollectionViewDataSource {
    @objc public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeedbackCollectionViewCell.defaultIdentifier, for: indexPath) as! FeedbackCollectionViewCell
        let item = sections[indexPath.row]
        
        cell.titleLabel.text = item.title
        cell.imageView.tintColor = .clear
        cell.imageView.image = item.image
        
        return cell
    }
    
    @objc public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    @objc public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections.count
    }
    
    @objc public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // In case the view is scrolled, dismiss the feedback window immediately
        // and reset the `progressBar` back to a full progress.
        abortAutodismiss()
        progressBar.progress = 1.0
    }
}

extension FeedbackViewController: UICollectionViewDelegate {
    @objc public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        abortAutodismiss()
        let item = sections[indexPath.row]
        sendFeedbackHandler?(item)
    }
}

extension FeedbackViewController: UICollectionViewDelegateFlowLayout {
    @objc public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = collectionView.bounds.width
        // 3 columns and 2 rows in portrait mode.
        // 6 columns and 1 row in landscape mode.
        let width = traitCollection.verticalSizeClass == .compact
            ? floor(availableWidth / CGFloat(sections.count))
            : floor(availableWidth / CGFloat(sections.count / 2))
        let item = sections[indexPath.row]
        let titleHeight = item.title.height(constrainedTo: width, font: FeedbackCollectionViewCell.Constants.titleFont)
        let cellHeight: CGFloat = FeedbackCollectionViewCell.Constants.imageSize.height
                                  + FeedbackCollectionViewCell.Constants.padding
                                  + titleHeight
                                  + FeedbackViewController.verticalCellPadding
        return CGSize(width: width, height: cellHeight )
    }
}

extension String {
    func height(constrainedTo width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        return ceil(boundingBox.height)
    }
}
