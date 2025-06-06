import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramPermissions
import TelegramNotices
import ContactsPeerItem
import SearchUI
import TelegramPermissionsUI
import AppBundle
import StickerResources
import ContextUI
import QrCodeUI
import StoryContainerScreen
import ChatListHeaderComponent
import TelegramIntents
import UndoUI
import ShareController

private final class HeaderContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView

    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class SortHeaderButton: HighlightableButtonNode {
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    private let textNode: ImmediateTextNode
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?

    init(presentationData: PresentationData) {
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        self.textNode = ImmediateTextNode()
        self.textNode.displaysAsynchronously = false

        super.init()

        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.addSubnode(self.textNode)
        self.addSubnode(self.containerNode)

        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }

        self.update(theme: presentationData.theme, strings: presentationData.strings)
    }

    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }

    func update(theme: PresentationTheme, strings: PresentationStrings) {
        self.textNode.attributedText = NSAttributedString(string: strings.Contacts_Sort, font: Font.regular(17.0), textColor: theme.rootController.navigationBar.accentTextColor)
        let size = self.textNode.updateLayout(CGSize(width: 100.0, height: 44.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((44.0 - size.height) / 2.0)), size: size)
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: 44.0))
        self.referenceNode.frame = self.containerNode.bounds
        
        self.accessibilityLabel = strings.Contacts_Sort
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let size = self.textNode.updateLayout(CGSize(width: 100.0, height: 44.0))
        
        return CGSize(width: size.width, height: 44.0)
    }

    func onLayout() {
    }
}

public class ContactsController: ViewController {
    private let context: AccountContext
    
    private var contactsNode: ContactsControllerNode {
        return self.displayNode as! ContactsControllerNode
    }
    private var validLayout: ContainerViewLayout?
    
    private let index: PresentationPersonNameOrder = .lastFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private var authorizationDisposable: Disposable?
    private var selectionDisposable: Disposable?
    private var actionDisposable = MetaDisposable()
    private let sortOrderPromise = Promise<ContactsSortOrder>()
    private let isInVoiceOver = ValuePromise<Bool>(false)
    
    public var switchToChatsController: (() -> Void)?
    
    public override func updateNavigationCustomData(_ data: Any?, progress: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.isNodeLoaded {
            self.contactsNode.contactListNode.updateSelectedChatLocation(data as? ChatLocation, progress: progress, transition: transition)
        }
    }
    
    private let sortButton: SortHeaderButton
    
    public init(context: AccountContext) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.sortButton = SortHeaderButton(presentationData: self.presentationData)
        
        //super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        super.init(navigationBarPresentationData: nil)
        
        self.tabBarItemContextActionType = .always
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Contacts_Title
        self.tabBarItem.title = self.presentationData.strings.Contacts_Title
        
        let icon: UIImage?
        if useSpecialTabBarIcons() {
            icon = UIImage(bundleImageName: "Chat List/Tabs/Holiday/IconContacts")
        } else {
            icon = UIImage(bundleImageName: "Chat List/Tabs/IconContacts")
        }
        
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
        if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabContacts"
        }
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: self.sortButton)
        self.navigationItem.leftBarButtonItem?.accessibilityLabel = self.presentationData.strings.Contacts_Sort
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
        self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Contacts_VoiceOver_AddContact
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }).strict()
        
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.authorizationDisposable = (combineLatest(DeviceAccess.authorizationStatus(subject: .contacts), combineLatest(context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .contacts)!), context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings]), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]))
            |> map { noticeView, preferences, sharedData -> (Bool, ContactsSortOrder) in
                let settings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? ContactsSettings.defaultSettings
                let synchronizeDeviceContacts: Bool = settings.synchronizeContacts
                
                let contactsSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]?.get(ContactSynchronizationSettings.self)
                
                let sortOrder: ContactsSortOrder = contactsSettings?.sortOrder ?? .presence
                if !synchronizeDeviceContacts {
                    return (true, sortOrder)
                }
                let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if let timestamp = timestamp, timestamp > 0 {
                    return (true, sortOrder)
                } else {
                    return (false, sortOrder)
                }
            })
            |> deliverOnMainQueue).start(next: { [weak self] status, suppressedAndSortOrder in
                if let strongSelf = self {
                    let (suppressed, sortOrder) = suppressedAndSortOrder
                    strongSelf.tabBarItem.badgeValue = status != .allowed && !suppressed ? "!" : nil
                    strongSelf.sortOrderPromise.set(.single(sortOrder))
                }
            }).strict()
        } else {
            self.sortOrderPromise.set(context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.contactSynchronizationSettings])
            |> map { sharedData -> ContactsSortOrder in
                let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.contactSynchronizationSettings]?.get(ContactSynchronizationSettings.self)
                return settings?.sortOrder ?? .presence
            })
        }
        
        self.sortButton.addTarget(self, action: #selector(self.sortPressed), forControlEvents: .touchUpInside)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.authorizationDisposable?.dispose()
        self.actionDisposable.dispose()
        self.selectionDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.sortButton.update(theme: self.presentationData.theme, strings: self.presentationData.strings)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.title = self.presentationData.strings.Contacts_Title
        self.tabBarItem.title = self.presentationData.strings.Contacts_Title
        if !self.presentationData.reduceMotion {
            self.tabBarItem.animationName = "TabContacts"
        } else {
            self.tabBarItem.animationName = nil
        }
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        if self.navigationItem.rightBarButtonItem != nil {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationAddIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.addPressed))
            self.navigationItem.rightBarButtonItem?.accessibilityLabel = self.presentationData.strings.Contacts_VoiceOver_AddContact
        }
    }
    
    override public func loadDisplayNode() {
        let sortOrderSignal: Signal<ContactsSortOrder, NoError> = combineLatest(self.sortOrderPromise.get(), self.isInVoiceOver.get())
        |> map { sortOrder, isInVoiceOver in
            if isInVoiceOver {
                return .natural
            } else {
                return sortOrder
            }
        }
        self.displayNode = ContactsControllerNode(context: self.context, sortOrder: sortOrderSignal |> distinctUntilChanged, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, controller: self)
        self._ready.set(combineLatest(queue: .mainQueue(),
            self.contactsNode.contactListNode.ready,
            self.contactsNode.storiesReady.get()
        )
        |> filter { a, b in
            return a && b
        }
        |> take(1)
        |> map { _ -> Bool in true })
        
        self.contactsNode.navigationBar = self.navigationBar
        
        let openPeer: (ContactListPeer, Bool) -> Void = { [weak self] peer, fromSearch in
            if let strongSelf = self {
                switch peer {
                    case let .peer(peer, _, _):
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            var scrollToEndIfExists = false
                            if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                                scrollToEndIfExists = true
                            }
                            
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(EnginePeer(peer)), purposefulAction: { [weak self] in
                                if fromSearch {
                                    self?.deactivateSearch(animated: false)
                                    self?.switchToChatsController?()
                                }
                                }, scrollToEndIfExists: scrollToEndIfExists, options: [.removeOnMasterDetails], completion: { [weak self] _ in
                                if let strongSelf = self {
                                    strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                                }
                            }))
                        }
                    case let .deviceContact(id, _):
                        let _ = ((strongSelf.context.sharedContext.contactDataManager?.extendedData(stableId: id) ?? .single(nil))
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { value in
                            guard let strongSelf = self, let value = value else {
                                return
                            }
                            (strongSelf.navigationController as? NavigationController)?.pushViewController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .vcard(nil, id, value), completed: nil, cancelled: nil), completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                                }
                            })
                        })
                }
            }
        }
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { peer in
            openPeer(peer, true)
        }
        
        self.contactsNode.contactListNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: "https://teamgram.net/privacy", forceExternal: true, presentationData: strongSelf.presentationData, navigationController: strongSelf.navigationController as? NavigationController, dismissInput: {})
            }
        }
        
        self.contactsNode.contactListNode.suppressPermissionWarning = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                })
            }
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer, _, _, _ in
            guard let self else {
                return
            }
            if let _ = self.contactsNode.contactListNode.selectionState {
                self.contactsNode.contactListNode.updateSelectionState({ current in
                    if let updatedState = current?.withToggledPeerId(peer.id), !updatedState.selectedPeerIndices.isEmpty {
                        return updatedState
                    } else {
                        return nil
                    }
                })
            } else {
                openPeer(peer, false)
            }
        }
        
        self.contactsNode.requestAddContact = { [weak self] phoneNumber in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                strongSelf.context.sharedContext.openAddContact(context: strongSelf.context, firstName: "", lastName: "", phoneNumber: phoneNumber, label: defaultContactLabel, present: { [weak self] controller, arguments in
                    self?.present(controller, in: .window(.root), with: arguments)
                }, pushController: { [weak self] controller in
                    (self?.navigationController as? NavigationController)?.pushViewController(controller)
                }, completed: {
                    self?.deactivateSearch(animated: false)
                })
            }
        }
        
        self.contactsNode.openPeopleNearby = { [weak self] in
            let _ = (DeviceAccess.authorizationStatus(subject: .location(.tracking))
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] status in
                guard let strongSelf = self else {
                    return
                }
                let presentPeersNearby = {
                    let controller = strongSelf.context.sharedContext.makePeersNearbyController(context: strongSelf.context)
                    controller.navigationPresentation = .master
                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                        var controllers = navigationController.viewControllers.filter { !($0 is PermissionController) }
                        controllers.append(controller)
                        navigationController.setViewControllers(controllers, animated: true)
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                    }
                }
                
                switch status {
                    case .allowed:
                        presentPeersNearby()
                    default:
                        let controller = PermissionController(context: strongSelf.context, splashScreen: false)
                        controller.setState(.permission(.nearbyLocation(status: PermissionRequestStatus(accessType: status))), animated: false)
                        controller.navigationPresentation = .master
                        controller.proceed = { result in
                            if result {
                                presentPeersNearby()
                            } else {
                                let _ = (strongSelf.navigationController as? NavigationController)?.popViewController(animated: true)
                            }
                        }
                        if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                            navigationController.pushViewController(controller, completion: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                                }
                            })
                        }
                }
            })
        }
        
        self.contactsNode.openInvite = { [weak self] in
            let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
            |> take(1)
            |> deliverOnMainQueue).start(next: { value in
                guard let strongSelf = self else {
                    return
                }
                switch value {
                    case .allowed:
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(InviteContactsController(context: strongSelf.context), completion: {
                            if let strongSelf = self {
                                strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                            }
                        })
                    case .notDetermined:
                        DeviceAccess.authorizeAccess(to: .contacts)
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                    default:
                        let presentationData = strongSelf.presentationData
                        strongSelf.present(textAlertController(context: strongSelf.context, title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            self?.context.sharedContext.applicationBindings.openSettings()
                        })]), in: .window(.root))
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                }
            })
        }
        
        self.contactsNode.openQrScan = { [weak self] in
            if let strongSelf = self {
                let context = strongSelf.context
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                DeviceAccess.authorizeAccess(to: .camera(.qrCode), presentationData: presentationData, present: { c, a in
                    c.presentationArguments = a
                    context.sharedContext.mainWindow?.present(c, on: .root)
                }, openSettings: {
                    context.sharedContext.applicationBindings.openSettings()
                }, { [weak self] granted in
                    guard let strongSelf = self else {
                        return
                    }
                    guard granted else {
                        strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                        return
                    }
                    let controller = QrCodeScanScreen(context: strongSelf.context, subject: .peer)
                    controller.showMyCode = { [weak self, weak controller] in
                        if let strongSelf = self {
                            let _ = (strongSelf.context.account.postbox.loadedPeerWithId(strongSelf.context.account.peerId)
                            |> deliverOnMainQueue).start(next: { [weak self, weak controller] peer in
                                if let strongSelf = self, let controller = controller {
                                    controller.present(strongSelf.context.sharedContext.makeChatQrCodeScreen(context: strongSelf.context, peer: peer, threadId: nil, temporary: false), in: .window(.root))
                                }
                            })
                        }
                    }
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(controller, completion: {
                        if let strongSelf = self {
                            strongSelf.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
                        }
                    })
                })
            }
        }
        
        self.sortButton.contextAction = { [weak self] sourceNode, gesture in
            self?.presentSortMenu(sourceView: sourceNode.view, gesture: gesture)
        }
        
        let previousToolbarValue = Atomic<Toolbar?>(value: nil)
        self.selectionDisposable = (self.contactsNode.contactListNode.selectionStateSignal
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self, let layout = self.validLayout else {
                return
            }
            
            let toolbar: Toolbar?
            if let state, state.selectedPeerIndices.count > 0 {
                toolbar = Toolbar(leftAction: nil, rightAction: nil, middleAction: ToolbarAction(title: self.presentationData.strings.ContactList_DeleteConfirmation(Int32(state.selectedPeerIndices.count)), isEnabled: true, color: .custom(self.presentationData.theme.actionSheet.destructiveActionTextColor)))
            } else {
                toolbar = nil
            }
            
            let _ = self.contactsNode.updateNavigationBar(layout: layout, transition: .animated(duration: 0.2, curve: .easeInOut))
            
            var transition: ContainedViewLayoutTransition = .immediate
            let previousToolbar = previousToolbarValue.swap(toolbar)
            if (previousToolbar == nil) != (toolbar == nil) {
                transition = .animated(duration: 0.4, curve: .spring)
            }
            self.setToolbar(toolbar, transition: transition)
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func toolbarActionSelected(action: ToolbarActionOption) {
        guard case .middle = action, let selectionState = self.contactsNode.contactListNode.selectionState else {
            return
        }
        var peerIds: [EnginePeer.Id] = []
        for contactPeerId in selectionState.selectedPeerIndices.keys {
            if case let .peer(peerId) = contactPeerId {
                peerIds.append(peerId)
            }
        }
        self.requestDeleteContacts(peerIds: peerIds)
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.contactsNode.didAppear = true
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    private func searchContentNode() -> NavigationBarSearchContentNode? {
        if let navigationBarView = self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View {
            return navigationBarView.searchContentNode
        }
        return nil
    }
    
    private func chatListHeaderView() -> ChatListHeaderComponent.View? {
        if let navigationBarView = self.contactsNode.navigationBarView.view as? ChatListNavigationBar.View {
            if let componentView = navigationBarView.headerContent.view as? ChatListHeaderComponent.View {
                return componentView
            }
        }
        return nil
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.isInVoiceOver.set(layout.inVoiceOver)
        
        self.validLayout = layout
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
        
        self.contactsNode.openStories = { [weak self] peer, sourceNode in
            guard let self else {
                return
            }
            
            if let itemNode = sourceNode as? ContactsPeerItemNode {
                StoryContainerScreen.openPeerStories(context: self.context, peerId: peer.id, parentController: self, avatarNode: itemNode.avatarNode)
            }
        }
    }
    
    @objc private func sortPressed() {
        self.sortButton.contextAction?(self.sortButton.containerNode, nil)
    }
    
    private func activateSearch() {
        if let searchContentNode = self.searchContentNode() {
            self.contactsNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
        }
        self.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
    }
    
    private func deactivateSearch(animated: Bool) {
        if let searchContentNode = self.searchContentNode() {
            self.contactsNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode, animated: animated)
            self.requestLayout(transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    func presentSortMenu(sourceView: UIView, gesture: ContextGesture?) {
        let updateSortOrder: (ContactsSortOrder) -> Void = { [weak self] sortOrder in
            if let strongSelf = self {
                strongSelf.sortOrderPromise.set(.single(sortOrder))
                let _ = updateContactSettingsInteractively(accountManager: strongSelf.context.sharedContext.accountManager, { current -> ContactSynchronizationSettings in
                    var updated = current
                    updated.sortOrder = sortOrder
                    return updated
                }).start()
            }
        }
        
        let presentationData = self.presentationData
        let items: Signal<[ContextMenuItem], NoError> = self.context.sharedContext.accountManager.transaction { transaction in
            return transaction.getSharedData(ApplicationSpecificSharedDataKeys.contactSynchronizationSettings)
        }
        |> map { entry -> [ContextMenuItem] in
            let currentSettings: ContactSynchronizationSettings
            if let entry = entry?.get(ContactSynchronizationSettings.self) {
                currentSettings = entry
            } else {
                currentSettings = .defaultSettings
            }
            
            var items: [ContextMenuItem] = []
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Contacts_Sort_ByLastSeen, icon: { theme in return currentSettings.sortOrder == .presence ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil }, action: { _, f in
                f(.default)
                updateSortOrder(.presence)
            })))
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Contacts_Sort_ByName, icon: { theme in return currentSettings.sortOrder == .natural ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor) : nil }, action: { _, f in
                f(.default)
                updateSortOrder(.natural)
            })))
            return items
        }
        let contextController = ContextController(presentationData: self.presentationData, source: .reference(HeaderContextReferenceContentSource(controller: self, sourceView: sourceView)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    public func beginSelection(peerId: EnginePeer.Id) {
        self.contactsNode.contactListNode.updateSelectionState { _ in
            return ContactListNodeGroupSelectionState().withToggledPeerId(.peer(peerId))
        }
    }
    
    public func requestDeleteContacts(peerIds: [EnginePeer.Id]) {
        guard !peerIds.isEmpty else {
            return
        }
        let actionSheet = ActionSheetController(presentationData: self.presentationData)
        var items: [ActionSheetItem] = []
        
        let actionTitle: String
        if peerIds.count > 1 {
            actionTitle = self.presentationData.strings.ContactList_DeleteConfirmation(Int32(peerIds.count))
        } else {
            actionTitle = self.presentationData.strings.ContactList_DeleteConfirmationSingle
        }
        
        items.append(ActionSheetButtonItem(title: actionTitle, color: .destructive, action: { [weak self, weak actionSheet] in
            actionSheet?.dismissAnimated()
            
            guard let self else {
                return
            }
            
            self.contactsNode.contactListNode.updateSelectionState { _ in
                return nil
            }
            
            self.contactsNode.contactListNode.updatePendingRemovalPeerIds { state in
                var state = state
                for peerId in peerIds {
                    state.insert(peerId)
                }
                return state
            }
            
            let text = self.presentationData.strings.ContactList_DeletedContacts(Int32(peerIds.count))
            
            self.present(UndoOverlayController(presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(context: self.context, title: NSAttributedString(string: text), text: nil), elevatedLayout: false, animateInAsReplacement: true, action: { [weak self] value in
                guard let self else {
                    return false
                }
                if value == .commit {
                    let deleteContactsFromDevice: Signal<Never, NoError>
                    if let contactDataManager = self.context.sharedContext.contactDataManager {
                        deleteContactsFromDevice = combineLatest(peerIds.map { contactDataManager.deleteContactWithAppSpecificReference(peerId: $0) }
                        )
                        |> ignoreValues
                    } else {
                        deleteContactsFromDevice = .complete()
                    }
                    
                    let deleteSignal = self.context.engine.contacts.deleteContacts(peerIds: peerIds)
                    |> then(deleteContactsFromDevice)
                    
                    for peerId in peerIds {
                        deleteSendMessageIntents(peerId: peerId)
                    }
                    
                    self.contactsNode.contactListNode.updatePendingRemovalPeerIds { state in
                        var state = state
                        for peerId in peerIds {
                            state.remove(peerId)
                        }
                        return state
                    }
                    
                    let _ = deleteSignal.start()
                    
                    return true
                } else if value == .undo {
                    self.contactsNode.contactListNode.updatePendingRemovalPeerIds { state in
                        var state = state
                        for peerId in peerIds {
                            state.remove(peerId)
                        }
                        return state
                    }
                    return true
                }
                return false
            }), in: .current)
        }))
        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        self.present(actionSheet, in: .window(.root))
    }
    
    @objc func addPressed() {
        let _ = (DeviceAccess.authorizationStatus(subject: .contacts)
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            
            switch status {
                case .allowed:
                    let contactData = DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: "", lastName: "", phoneNumbers: [DeviceContactPhoneNumberData(label: "_$!<Mobile>!$_", value: "+")]), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: [], note: "")
                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                        navigationController.pushViewController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .create(peer: nil, contactData: contactData, isSharing: false, shareViaException: false, completion: { peer, stableId, contactData in
                            guard let strongSelf = self else {
                                return
                            }
                            if let peer = peer {
                                DispatchQueue.main.async {
                                    if let infoController = strongSelf.context.sharedContext.makePeerInfoController(context: strongSelf.context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                                        if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                                            navigationController.pushViewController(infoController)
                                        }
                                    }
                                }
                            } else {
                                if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController {
                                    navigationController.pushViewController(strongSelf.context.sharedContext.makeDeviceContactInfoController(context: ShareControllerAppAccountContext(context: strongSelf.context), environment: ShareControllerAppEnvironment(sharedContext: strongSelf.context.sharedContext), subject: .vcard(nil, stableId, contactData), completed: nil, cancelled: nil))
                                }
                            }
                        }), completed: nil, cancelled: nil))
                    }
                case .notDetermined:
                    DeviceAccess.authorizeAccess(to: .contacts)
                default:
                    let presentationData = strongSelf.presentationData
                    if let navigationController = strongSelf.context.sharedContext.mainWindow?.viewController as? NavigationController, let topController = navigationController.topViewController as? ViewController {
                        topController.present(textAlertController(context: strongSelf.context, title: presentationData.strings.AccessDenied_Title, text: presentationData.strings.Contacts_AccessDeniedError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.AccessDenied_Settings, action: {
                            self?.context.sharedContext.applicationBindings.openSettings()
                        })]), in: .window(.root))
                    }
            }
        })
    }
    
    override public func tabBarItemContextAction(sourceNode: ContextExtractedContentContainingNode, gesture: ContextGesture) {
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Contacts_AddContact, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddUser"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] c, f in
            c?.dismiss(completion: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.addPressed()
            })
        })))
        
        let controller = ContextController(presentationData: self.presentationData, source: .extracted(ContactsTabBarContextExtractedContentSource(controller: self, sourceNode: sourceNode)), items: .single(ContextController.Items(content: .list(items))), recognizer: nil, gesture: gesture)
        self.context.sharedContext.mainWindow?.presentInGlobalOverlay(controller)
    }
}

private final class ContactsTabBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = true
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    let actionsHorizontalAlignment: ContextActionsHorizontalAlignment = .center
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private final class ChatListHeaderBarContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
