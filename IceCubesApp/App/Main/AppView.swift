import Account
import AppAccount
import AVFoundation
import DesignSystem
import Env
import KeychainSwift
import MediaUI
import Network
import RevenueCat
import Status
import SwiftUI
import Timeline
import Models

@MainActor
struct AppView: View {
  @Environment(AppAccountsManager.self) private var appAccountsManager
  @Environment(UserPreferences.self) private var userPreferences
  @Environment(Theme.self) private var theme
  @Environment(StreamWatcher.self) private var watcher
  
  @Binding var selectedTab: Tab
  @Binding var sidebarRouterPath: RouterPath
    
  @State var accountsViewModel: [AppAccountViewModel] = []
  @State var popToRootTab: Tab = .other
  @State var iosTabs = iOSTabs.shared
  @State var sideBarLoadedTabs: Set<Tab> = Set()
  @State var accountViewSelectorVisisble: Bool = false
  
  var body: some View {
    if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
      sidebarView
    } else {
      tabBarView
    }
  }
  
  var availableTabs: [Tab] {
    if UIDevice.current.userInterfaceIdiom == .phone || horizontalSizeClass == .compact {
      return appAccountsManager.currentClient.isAuth ? iosTabs.tabs : Tab.loggedOutTab()
    }
    return appAccountsManager.currentClient.isAuth ? Tab.loggedInTabs() : Tab.loggedOutTab()
  }
    
  private var preferredHeight: CGFloat {
    var baseHeight: CGFloat = 310
    baseHeight += CGFloat(60 * accountsViewModel.count)
    return baseHeight
  }

  var tabBarView: some View {
    TabView(selection: .init(get: {
      selectedTab
    }, set: { newTab in
      if newTab == .post {
        appRouterPath.presentedSheet = .newStatusEditor(visibility: userPreferences.postVisibility)
        return
      }
      if newTab == selectedTab {
        /// Stupid hack to trigger onChange binding in tab views.
        popToRootTab = .other
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
          popToRootTab = selectedTab
        }
      }

      HapticManager.shared.fireHaptic(.tabSelection)
      SoundEffectManager.shared.playSound(.tabSelection)

      selectedTab = newTab
    })) {
      ForEach(availableTabs) { tab in
        tab.makeContentView(selectedTab: $selectedTab, popToRootTab: $popToRootTab)
          .tabItem {
            if userPreferences.showiPhoneTabLabel {
              tab.label
            } else {
              Image(systemName: tab.iconName)
            }
          }
          .tag(tab)
          .badge(badgeFor(tab: tab))
          .toolbarBackground(theme.primaryBackgroundColor.opacity(0.50), for: .tabBar)
      }
    }
    .gesture(DragGesture().onEnded({ value in
        if value.translation.height < 0 {
            var found = false
            var accountToSet : AppAccount = appAccountsManager.availableAccounts[0]
            for account in appAccountsManager.availableAccounts {
                if found {
                    accountToSet = account
                    break
                }
                if account.id == appAccountsManager.currentAccount.id {
                    found = true
                }
            }
            var transation = Transaction()
            transation.disablesAnimations = true
            withTransaction(transation) {
              appAccountsManager.currentAccount = accountToSet
              HapticManager.shared.fireHaptic(.notification(.success))
            }
        }
    }))
    .sheet(isPresented: $accountViewSelectorVisisble, content: {
        return AppAccountsSelectorView(routerPath: RouterPath(), accountsViewModel: $accountsViewModel, isPresented: $accountViewSelectorVisisble)
            .presentationDetents([.height(preferredHeight), .large])
            .presentationBackground(.thinMaterial)
            .presentationCornerRadius(16)
            .onAppear {
              refreshAccounts()
            }
    })
    .onLongPressGesture(perform: {
        accountViewSelectorVisisble = true
    })
    .id(appAccountsManager.currentClient.id)
    .withSheetDestinations(sheetDestinations: $appRouterPath.presentedSheet)
  }

  private func badgeFor(tab: Tab) -> Int {
    if tab == .notifications, selectedTab != tab,
       let token = appAccountsManager.currentAccount.oauthToken
    {
      return watcher.unreadNotificationsCount + (userPreferences.notificationsCount[token] ?? 0)
    }
    return 0
  }
  
  var sidebarView: some View {
    SideBarView(selectedTab: $selectedTab,
                popToRootTab: $popToRootTab,
                tabs: availableTabs)
    {
      HStack(spacing: 0) {
        TabView(selection: $selectedTab) {
          ForEach(availableTabs) { tab in
            tab
              .makeContentView(selectedTab: $selectedTab, popToRootTab: $popToRootTab)
              .tabItem {
                tab.label
              }
              .tag(tab)
          }
        }
        .introspect(.tabView, on: .iOS(.v17)) { (tabview: UITabBarController) in
          tabview.tabBar.isHidden = horizontalSizeClass == .regular
          tabview.customizableViewControllers = []
          tabview.moreNavigationController.isNavigationBarHidden = true
        }
        if horizontalSizeClass == .regular,
           appAccountsManager.currentClient.isAuth,
           userPreferences.showiPadSecondaryColumn
        {
          Divider().edgesIgnoringSafeArea(.all)
          notificationsSecondaryColumn
        }
      }
    }
    .environment(appRouterPath)
  }

  var notificationsSecondaryColumn: some View {
    NotificationsTab(selectedTab: .constant(.notifications),
                     popToRootTab: $popToRootTab, lockedType: nil)
      .environment(\.isSecondaryColumn, true)
      .frame(maxWidth: .secondaryColumnWidth)
      .id(appAccountsManager.currentAccount.id)
  }
    
    private func refreshAccounts() {
      accountsViewModel = []
      for account in appAccountsManager.availableAccounts {
        let viewModel: AppAccountViewModel = .init(appAccount: account, isInNavigation: false, showBadge: true)
        accountsViewModel.append(viewModel)
      }
    }
}
