import ComposableArchitecture
import ZcashLightClientKit

typealias AppReducer = Reducer<AppState, AppAction, AppEnvironment>
typealias AppStore = Store<AppState, AppAction>
typealias AppViewStore = ViewStore<AppState, AppAction>

// MARK: - State

struct AppState: Equatable {
    enum Route: Equatable {
        case welcome
        case startup
        case onboarding
        case sandbox
        case home
        case phraseValidation
        case phraseDisplay
    }
    
    var appInitializationState: InitializationState = .uninitialized
    var homeState: HomeState
    var onboardingState: OnboardingFlowState
    var phraseValidationState: RecoveryPhraseValidationFlowState
    var phraseDisplayState: RecoveryPhraseDisplayState
    var prevRoute: Route?
    var internalRoute: Route = .welcome
    var sandboxState: SandboxState
    var storedWallet: StoredWallet?
    var welcomeState: WelcomeState
    
    var route: Route {
        get { internalRoute }
        set {
            prevRoute = internalRoute
            internalRoute = newValue
        }
    }
}

// MARK: - Action

enum AppAction: Equatable {
    case appDelegate(AppDelegateAction)
    case checkBackupPhraseValidation
    case checkWalletInitialization
    case createNewWallet
    case home(HomeAction)
    case initializeSDK
    case nukeWallet
    case onboarding(OnboardingFlowAction)
    case phraseDisplay(RecoveryPhraseDisplayAction)
    case phraseValidation(RecoveryPhraseValidationFlowAction)
    case respondToWalletInitializationState(InitializationState)
    case sandbox(SandboxAction)
    case updateRoute(AppState.Route)
    case welcome(WelcomeAction)
}

// MARK: - Environment

struct AppEnvironment {
    let SDKSynchronizer: WrappedSDKSynchronizer
    let databaseFiles: WrappedDatabaseFiles
    let mnemonic: WrappedMnemonic
    let scheduler: AnySchedulerOf<DispatchQueue>
    let walletStorage: WrappedWalletStorage
    let derivationTool: WrappedDerivationTool
    let zcashSDKEnvironment: ZCashSDKEnvironment
}

extension AppEnvironment {
    static let live = AppEnvironment(
        SDKSynchronizer: LiveWrappedSDKSynchronizer(),
        databaseFiles: .live(),
        mnemonic: .live,
        scheduler: DispatchQueue.main.eraseToAnyScheduler(),
        walletStorage: .live(),
        derivationTool: .live(),
        zcashSDKEnvironment: .mainnet
    )

    static let mock = AppEnvironment(
        SDKSynchronizer: LiveWrappedSDKSynchronizer(),
        databaseFiles: .live(),
        mnemonic: .mock,
        scheduler: DispatchQueue.main.eraseToAnyScheduler(),
        walletStorage: .live(),
        derivationTool: .live(derivationTool: DerivationTool(networkType: .mainnet)),
        zcashSDKEnvironment: .mainnet
    )
}

// MARK: - Reducer

extension AppReducer {
    private struct ListenerId: Hashable {}

    static let `default` = AppReducer.combine(
        [
            appReducer,
            homeReducer,
            onboardingReducer,
            phraseValidationReducer,
            phraseDisplayReducer,
            routeReducer,
            sandboxReducer
        ]
    )
    .debug()

    private static let appReducer = AppReducer { state, action, environment in
        switch action {
        case .appDelegate(.didFinishLaunching):
            /// We need to fetch data from keychain, in order to be 100% sure the kecyhain can be read we delay the check a bit
            return Effect(value: .checkWalletInitialization)
                .delay(for: 0.02, scheduler: environment.scheduler)
                .eraseToEffect()
            
            /// Evaluate the wallet's state based on keychain keys and database files presence
        case .checkWalletInitialization:
            let walletState = walletInitializationState(environment)
            return Effect(value: .respondToWalletInitializationState(walletState))
            
            /// Respond to all possible states of the wallet and initiate appropriate side effects including errors handling
        case .respondToWalletInitializationState(let walletState):
            switch walletState {
            case .failed:
                // TODO: error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
                state.appInitializationState = .failed
            case .keysMissing:
                // TODO: error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
                state.appInitializationState = .keysMissing
            case .initialized, .filesMissing:
                if walletState == .filesMissing {
                    state.appInitializationState = .filesMissing
                }
                return .concatenate(
                    Effect(value: .initializeSDK),
                    Effect(value: .checkBackupPhraseValidation)
                )
            case .uninitialized:
                state.appInitializationState = .uninitialized
                return Effect(value: .updateRoute(.onboarding))
                    .delay(for: 3, scheduler: environment.scheduler)
                    .eraseToEffect()
                    .cancellable(id: ListenerId(), cancelInFlight: true)
            }
            
            return .none

            /// Stored wallet is present, database files may or may not be present, trying to initialize app state variables and environments.
            /// When initialization succeeds user is taken to the home screen.
        case .initializeSDK:
            do {
                state.storedWallet = try environment.walletStorage.exportWallet()
                
                guard let storedWallet = state.storedWallet else {
                    state.appInitializationState = .failed
                    // TODO: fatal error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
                    return .none
                }
                
                try environment.mnemonic.isValid(storedWallet.seedPhrase)
                
                let birthday = state.storedWallet?.birthday ?? environment.zcashSDKEnvironment.defaultBirthday
                
                let initializer = try prepareInitializer(
                    for: storedWallet.seedPhrase,
                    birthday: birthday,
                    with: environment
                )
                try environment.SDKSynchronizer.prepareWith(initializer: initializer)
                try environment.SDKSynchronizer.start()
            } catch {
                state.appInitializationState = .failed
                // TODO: error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
            }
            return .none

        case .checkBackupPhraseValidation:
            guard let storedWallet = state.storedWallet else {
                state.appInitializationState = .failed
                // TODO: fatal error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
                return .none
            }

            var landingRoute: AppState.Route = .home
            
            if !storedWallet.hasUserPassedPhraseBackupTest {
                do {
                    let phraseWords = try environment.mnemonic.asWords(storedWallet.seedPhrase)
                    
                    let recoveryPhrase = RecoveryPhrase(words: phraseWords)
                    state.phraseDisplayState.phrase = recoveryPhrase
                    state.phraseValidationState = RecoveryPhraseValidationFlowState.random(phrase: recoveryPhrase)
                    landingRoute = .phraseDisplay
                } catch {
                    // TODO: - merge with issue 201 (https://github.com/zcash/secant-ios-wallet/issues/201) and its Error States
                    return .none
                }
            }
            
            state.appInitializationState = .initialized
            return Effect(value: .updateRoute(landingRoute))
                .delay(for: 3, scheduler: environment.scheduler)
                .eraseToEffect()
                .cancellable(id: ListenerId(), cancelInFlight: true)
            
        case .createNewWallet:
            do {
                // get the random english mnemonic
                let randomPhrase = try environment.mnemonic.randomMnemonic()
                let birthday = try environment.zcashSDKEnvironment.lightWalletService.latestBlockHeight()
                
                // store the wallet to the keychain
                try environment.walletStorage.importWallet(randomPhrase, birthday, .english, false)
                
                // start the backup phrase validation test
                let randomPhraseWords = try environment.mnemonic.asWords(randomPhrase)
                let recoveryPhrase = RecoveryPhrase(words: randomPhraseWords)
                state.phraseDisplayState.phrase = recoveryPhrase
                state.phraseValidationState = RecoveryPhraseValidationFlowState.random(phrase: recoveryPhrase)
                
                return .concatenate(
                    Effect(value: .initializeSDK),
                    Effect(value: .phraseValidation(.displayBackedUpPhrase))
                )
            } catch {
                // TODO: - merge with issue 201 (https://github.com/zcash/secant-ios-wallet/issues/201) and its Error States
            }

            return .none

        case .phraseValidation(.succeed):
            do {
                try environment.walletStorage.markUserPassedPhraseBackupTest()
            } catch {
                // TODO: error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
            }
            return .none

        case .nukeWallet:
            environment.walletStorage.nukeWallet()
            do {
                try environment.databaseFiles.nukeDbFilesFor(environment.zcashSDKEnvironment.network)
            } catch {
                // TODO: error we need to handle, issue #221 (https://github.com/zcash/secant-ios-wallet/issues/221)
            }
            return .none

        case .welcome(.debugMenuStartup), .home(.debugMenuStartup):
            return .concatenate(
                Effect.cancel(id: ListenerId()),
                Effect(value: .updateRoute(.startup))
            )

        case .onboarding(.importWallet(.successfullyRecovered)):
            return Effect(value: .updateRoute(.home))

        case .onboarding(.importWallet(.initializeSDK)):
            return Effect(value: .initializeSDK)

            /// Default is meaningful here because there's `routeReducer` handling routes and this reducer is handling only actions. We don't here plenty of unused cases.
        default:
            return .none
        }
    }

    private static let routeReducer = AppReducer { state, action, _ in
        switch action {
        case let .updateRoute(route):
            state.route = route

        case .sandbox(.reset):
            state.route = .startup

        case .onboarding(.createNewWallet):
            return Effect(value: .createNewWallet)

        case .phraseValidation(.proceedToHome):
            state.route = .home

        case .phraseValidation(.displayBackedUpPhrase),
            .phraseDisplay(.createPhrase):
            state.route = .phraseDisplay

        case .phraseDisplay(.finishedPressed):
            // user is still supposed to do the backup phrase validation test
            if state.prevRoute == .welcome || state.prevRoute == .onboarding {
                state.route = .phraseValidation
            }
            // user wanted to see the backup phrase once again (at validation finished screen)
            if state.prevRoute == .phraseValidation {
                state.route = .home
            }

            /// Default is meaningful here because there's `appReducer` handling actions and this reducer is handling only routes. We don't here plenty of unused cases.
        default:
            break
        }

        return .none
    }

    private static let homeReducer: AppReducer = HomeReducer.default.pullback(
        state: \AppState.homeState,
        action: /AppAction.home,
        environment: { environment in
            HomeEnvironment(
                mnemonic: environment.mnemonic,
                scheduler: environment.scheduler,
                walletStorage: environment.walletStorage,
                derivationTool: environment.derivationTool,
                SDKSynchronizer: environment.SDKSynchronizer
            )
        }
    )

    private static let onboardingReducer: AppReducer = OnboardingFlowReducer.default.pullback(
        state: \AppState.onboardingState,
        action: /AppAction.onboarding,
        environment: { environment in
            OnboardingFlowEnvironment(
                mnemonic: environment.mnemonic,
                walletStorage: environment.walletStorage,
                zcashSDKEnvironment: environment.zcashSDKEnvironment
            )
        }
    )

    private static let phraseValidationReducer: AppReducer = RecoveryPhraseValidationFlowReducer.default.pullback(
        state: \AppState.phraseValidationState,
        action: /AppAction.phraseValidation,
        environment: { _ in RecoveryPhraseValidationFlowEnvironment.demo }
    )

    private static let phraseDisplayReducer: AppReducer = RecoveryPhraseDisplayReducer.default.pullback(
        state: \AppState.phraseDisplayState,
        action: /AppAction.phraseDisplay,
        environment: { _ in RecoveryPhraseDisplayEnvironment.live }
    )
    
    private static let sandboxReducer: AppReducer = SandboxReducer.default.pullback(
        state: \AppState.sandboxState,
        action: /AppAction.sandbox,
        environment: { _ in SandboxEnvironment() }
    )

    private static let welcomeReducer: AppReducer = WelcomeReducer.default.pullback(
        state: \AppState.welcomeState,
        action: /AppAction.welcome,
        environment: { _ in WelcomeEnvironment() }
    )
}

extension AppReducer {
    static func walletInitializationState(_ environment: AppEnvironment) -> InitializationState {
        var keysPresent = false
        do {
            keysPresent = try environment.walletStorage.areKeysPresent()
            let databaseFilesPresent = try environment.databaseFiles.areDbFilesPresentFor(
                environment.zcashSDKEnvironment.network
            )
            
            switch (keysPresent, databaseFilesPresent) {
            case (false, false):
                return .uninitialized
            case (false, true):
                return .keysMissing
            case (true, false):
                return .filesMissing
            case (true, true):
                return .initialized
            }
        } catch DatabaseFiles.DatabaseFilesError.filesPresentCheck {
            if keysPresent {
                return .filesMissing
            }
        } catch WalletStorage.WalletStorageError.uninitializedWallet {
            do {
                if try environment.databaseFiles.areDbFilesPresentFor(
                    environment.zcashSDKEnvironment.network
                ) {
                    return .keysMissing
                }
            } catch {
                return .uninitialized
            }
        } catch {
            return .failed
        }
        
        return .uninitialized
    }
    
    static func prepareInitializer(
        for seedPhrase: String,
        birthday: BlockHeight,
        with environment: AppEnvironment
    ) throws -> Initializer {
        do {
            let seedBytes = try environment.mnemonic.toSeed(seedPhrase)
            let viewingKeys = try environment.derivationTool.deriveUnifiedViewingKeysFromSeed(seedBytes, 1)
            
            let network = environment.zcashSDKEnvironment.network
            
            let initializer = Initializer(
                cacheDbURL: try environment.databaseFiles.cacheDbURLFor(network),
                dataDbURL: try environment.databaseFiles.dataDbURLFor(network),
                pendingDbURL: try environment.databaseFiles.pendingDbURLFor(network),
                endpoint: environment.zcashSDKEnvironment.endpoint,
                network: environment.zcashSDKEnvironment.network,
                spendParamsURL: try environment.databaseFiles.spendParamsURLFor(network),
                outputParamsURL: try environment.databaseFiles.outputParamsURLFor(network),
                viewingKeys: viewingKeys,
                walletBirthday: birthday
            )
            
            return initializer
        } catch {
            throw SDKInitializationError.failed
        }
    }
}

// MARK: Placeholders

extension AppState {
    static var placeholder: Self {
        .init(
            homeState: .placeholder,
            onboardingState: .init(
                importWalletState: .placeholder
            ),
            phraseValidationState: RecoveryPhraseValidationFlowState.placeholder,
            phraseDisplayState: RecoveryPhraseDisplayState(
                phrase: .placeholder
            ),
            sandboxState: .placeholder,
            welcomeState: .placeholder
        )
    }
}

extension AppStore {
    static var placeholder: AppStore {
        AppStore(
            initialState: .placeholder,
            reducer: .default,
            environment: .live
        )
    }
}
