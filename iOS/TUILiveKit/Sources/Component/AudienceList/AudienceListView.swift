//
//  AudienceListView.swift
//  TUILiveKit
//
//  Created by WesleyLei on 2023/10/20.
//

import Foundation
import RTCCommon
import RTCRoomEngine
import Combine

class UserInfoCell: UICollectionViewCell {
    var userInfo: TUIUserInfo? {
        didSet {
            if let url = URL(string: userInfo?.avatarUrl ?? "") {
                avatarImageView.kf.setImage(with: url, placeholder:UIImage.avatarPlaceholderImage)
            } else {
                avatarImageView.image = .avatarPlaceholderImage
            }
        }
    }

    lazy var avatarImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.layer.cornerRadius = 24.scale375() * 0.5
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.g1.withAlphaComponent(0.4).cgColor
        contentView.addSubview(imageView)
        return imageView
    }()

    private var isViewReady = false
    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard !isViewReady else {
            return
        }
        isViewReady = true
        contentView.backgroundColor = .clear
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

class AudienceListView: RTCBaseView {
    var onUserManageButtonClicked: ((TUIUserInfo) -> Void)?
    private let cellId = "TUIVideoSeatCell_Normal"
    
    // Set this value to change max display count
    private let displayAvatarCount = 3
    
    // MARK: - private property.
    private let service: AudienceListService = AudienceListService()
    private var state: AudienceListState {
        service.state
    }
    private lazy var observer: AudienceListObserver = AudienceListObserver(state: state, service: service)
    private lazy var audienceListPanel = AudienceListPanelView(state: state)
    private var listUser: [TUIUserInfo] = []
    private var cancellableSet: Set<AnyCancellable> = []
    private weak var popupViewController: UIViewController?
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 24.scale375(), height: 24.scale375())
        layout.minimumLineSpacing = 4.scale375()
        layout.minimumInteritemSpacing = 4.scale375()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.semanticContentAttribute = .forceRightToLeft
        collectionView.isUserInteractionEnabled = true
        collectionView.contentMode = .scaleToFill
        collectionView.dataSource = self
        collectionView.register(UserInfoCell.self, forCellWithReuseIdentifier: cellId)
        return collectionView
    }()
    
    private lazy var numberBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.g1.withAlphaComponent(0.4)
        view.layer.cornerRadius = 10.scale375Height()
        return view
    }()
    
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.textColor = .g7
        label.font = .customFont(ofSize: 10)
        label.textAlignment = .center
        return label
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .liveBundleImage("live_selection_arrow_icon")
        return imageView
    }()

    func initialize(roomId: String) {
        TUIRoomEngine.sharedInstance().addObserver(observer)
        service.initRoomInfo(roomId: roomId)
    }
    
    override func constructViewHierarchy() {
        backgroundColor = .clear
        addSubview(collectionView)
        addSubview(numberBackgroundView)
        numberBackgroundView.addSubview(numberLabel)
        numberBackgroundView.addSubview(imageView)
    }
    
    override func activateConstraints() {
        collectionView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.height.equalTo(24.scale375())
            make.width.equalTo((displayAvatarCount * 24 + (displayAvatarCount - 1) * 4).scale375())
        }
        numberBackgroundView.snp.makeConstraints { make in
            make.leading.equalTo(collectionView.snp.trailing).offset(4.scale375())
            make.centerY.height.equalTo(collectionView)
            make.trailing.equalToSuperview()
        }
        let numberMaxWidth = getMaxWidthFromLabel(numberLabel, maxText: "999999")
        let numberMinWidth = getMaxWidthFromLabel(numberLabel, maxText: "0")
        numberLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4.scale375())
            make.centerY.height.equalToSuperview()
            make.width.lessThanOrEqualTo(numberMaxWidth)
            make.width.greaterThanOrEqualTo(numberMinWidth)
            make.trailing.equalTo(imageView.snp.leading)
        }
        imageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4.scale375())
            make.centerY.equalToSuperview()
            make.width.height.equalTo(8.scale375())
        }
    }
    
    private func getMaxWidthFromLabel(_ label: UILabel, maxText: String) -> CGFloat {
        let tmpLabel = UILabel(frame: .zero)
        tmpLabel.numberOfLines = 1
        tmpLabel.font = label.font
        tmpLabel.text = maxText
        tmpLabel.sizeToFit()
        return tmpLabel.frame.size.width
    }
    
    override func setupViewStyle() {
        backgroundColor = .clear
    }
    
    override func bindInteraction() {
        state.$audienceList
            .combineLatest(state.$audienceCount)
            .receive(on: RunLoop.main)
            .sink { [weak self] audienceList, audienceCount in
                guard let self = self else { return }
                self.listUser = audienceList
                self.collectionView.reloadData()
                
                let count = audienceCount > kMaxShowUserCount ? audienceCount : audienceList.count
                self.updateUserCount(count: count)
            }
            .store(in: &cancellableSet)
        
        state.roomDismissedSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] dismissedRoomId in
                guard let self = self, dismissedRoomId == state.roomId else { return }
                popupViewController?.dismiss(animated: true)
                popupViewController = nil
            }.store(in: &cancellableSet)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(containerTapAction))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
        audienceListPanel.onUserManageButtonClicked = onUserManageButtonClicked
    }
    
    deinit {
        TUIRoomEngine.sharedInstance().removeObserver(observer)
    }
    
    private func updateUserCount(count: Int) {
        numberLabel.text = "\(count)"
        numberLabel.sizeToFit()
        let maxWidth = getMaxWidthFromLabel(numberLabel, maxText: "999999")
        let currentWidth = numberLabel.frame.size.width
        numberLabel.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(4.scale375())
            make.centerY.height.equalToSuperview()
            make.trailing.equalTo(imageView.snp.leading)
            make.width.equalTo(min(maxWidth, currentWidth))
        }
        superview?.layoutIfNeeded()
    }
}

// MARK: - UICollectionViewDataSource
extension AudienceListView: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return listUser.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! UserInfoCell
        if indexPath.item >= listUser.count {
            return cell
        }
        let userInfo = listUser[indexPath.item]
        cell.userInfo = userInfo
        return cell
    }
}

extension AudienceListView {
    @objc func containerTapAction() {
        if let vc = WindowUtils.getCurrentWindowViewController() {
            popupViewController = vc
            let menuContainerView = MenuContainerView(contentView: audienceListPanel)
            audienceListPanel.onBackButtonClickedClosure = { [weak self] in
                guard let self = self else { return }
                popupViewController?.dismiss(animated: true)
                popupViewController = nil
            }
            menuContainerView.blackAreaClickClosure = { [weak self] in
                guard let self = self else { return }
                popupViewController?.dismiss(animated: true)
                popupViewController = nil
            }
            let viewController = PopupViewController(contentView: menuContainerView)
            popupViewController?.present(viewController, animated: true)
        }
    }
}
