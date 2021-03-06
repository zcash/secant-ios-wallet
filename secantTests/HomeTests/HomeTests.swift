//
//  HomeTests.swift
//  secantTests
//
//  Created by Lukáš Korba on 02.06.2022.
//

import XCTest
@testable import secant_testnet
import ComposableArchitecture
import ZcashLightClientKit

// swiftlint:disable type_body_length
class HomeTests: XCTestCase {
    func testSynchronizerStateChanged_AnyButSynced() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let store = TestStore(
            initialState: .placeholder,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.synchronizerStateChanged(.downloading))
        
        testScheduler.advance(by: 0.01)
        
        store.receive(.updateSynchronizerStatus)
        
        let balance = WalletBalance(verified: Zatoshi(12_345_000), total: Zatoshi(12_345_000))
        store.receive(.updateBalance(balance)) { state in
            state.totalBalance = Zatoshi(12_345_000)
            state.verifiedBalance = Zatoshi(12_345_000)
        }
    }

    /// When the synchronizer status change to .synced, several things happen
    /// 1. the .updateSynchronizerStatus is called
    /// 2. the side effect to update the transactions history is called
    /// 3. the side effect to update the balance is called
    func testSynchronizerStateChanged_Synced() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let store = TestStore(
            initialState: .placeholder,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.synchronizerStateChanged(.synced))
        
        testScheduler.advance(by: 0.01)
        
        // ad 1.
        store.receive(.updateSynchronizerStatus)

        // ad 2.
        let transactionsHelper: [TransactionStateMockHelper] = [
            TransactionStateMockHelper(date: 1651039202, amount: Zatoshi(1), status: .paid(success: false), uuid: "1"),
            TransactionStateMockHelper(date: 1651039101, amount: Zatoshi(2), uuid: "2"),
            TransactionStateMockHelper(date: 1651039000, amount: Zatoshi(3), status: .paid(success: true), uuid: "3"),
            TransactionStateMockHelper(date: 1651039505, amount: Zatoshi(4), uuid: "4"),
            TransactionStateMockHelper(date: 1651039404, amount: Zatoshi(5), uuid: "5")
        ]
        let walletEvents: [WalletEvent] = transactionsHelper.map {
            let transaction = TransactionState.placeholder(
                amount: $0.amount,
                fee: Zatoshi(10),
                shielded: $0.shielded,
                status: $0.status,
                timestamp: $0.date,
                uuid: $0.uuid
            )
            return WalletEvent(id: transaction.id, state: .send(transaction), timestamp: transaction.timestamp)
        }
        
        store.receive(.updateWalletEvents(walletEvents))
        
        // ad 3.
        let balance = WalletBalance(verified: Zatoshi(12_345_000), total: Zatoshi(12_345_000))

        store.receive(.updateBalance(balance)) { state in
            state.verifiedBalance = Zatoshi(12_345_000)
            state.totalBalance = Zatoshi(12_345_000)
        }
    }
    
    func testWalletEventsPartial_to_FullDrawer() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let homeState = HomeState(
            drawerOverlay: .partial,
            profileState: .placeholder,
            requestState: .placeholder,
            sendState: .placeholder,
            scanState: .placeholder,
            synchronizerStatusSnapshot: .default,
            totalBalance: Zatoshi.zero,
            walletEventsState: .emptyPlaceHolder,
            verifiedBalance: Zatoshi.zero
        )
        
        let store = TestStore(
            initialState: homeState,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.walletEvents(.updateRoute(.all))) { state in
            state.walletEventsState.route = .all
        }
                   
        store.receive(.updateDrawer(.full)) { state in
            state.drawerOverlay = .full
            state.walletEventsState.isScrollable = true
        }
    }
    
    func testWalletEventsFull_to_PartialDrawer() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let homeState = HomeState(
            drawerOverlay: .full,
            profileState: .placeholder,
            requestState: .placeholder,
            sendState: .placeholder,
            scanState: .placeholder,
            synchronizerStatusSnapshot: .default,
            totalBalance: Zatoshi.zero,
            walletEventsState: .emptyPlaceHolder,
            verifiedBalance: Zatoshi.zero
        )
        
        let store = TestStore(
            initialState: homeState,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.walletEvents(.updateRoute(.latest))) { state in
            state.walletEventsState.route = .latest
        }
                   
        store.receive(.updateDrawer(.partial)) { state in
            state.drawerOverlay = .partial
            state.walletEventsState.isScrollable = false
        }
    }
    
    /// The .onAppear action is important to register for the synchronizer state updates.
    /// The integration tests make sure registrations and side effects are properly implemented.
    func testOnAppear() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let store = TestStore(
            initialState: .placeholder,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.onAppear) { state in
            state.requiredTransactionConfirmations = 10
        }
        
        testScheduler.advance(by: 0.01)
        
        // expected side effects as a result of .onAppear registration
        store.receive(.synchronizerStateChanged(.unknown))
        store.receive(.updateSynchronizerStatus)
        
        let balance = WalletBalance(verified: Zatoshi(12_345_000), total: Zatoshi(12_345_000))
        store.receive(.updateBalance(balance)) { state in
            state.totalBalance = Zatoshi(12_345_000)
            state.verifiedBalance = Zatoshi(12_345_000)
        }

        // long-living (cancelable) effects need to be properly canceled.
        // the .onDisappear action cancles the observer of the synchronizer status change.
        store.send(.onDisappear)
    }
    
    func testQuickRescan_ResetToHomeScreen() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let homeState = HomeState(
            route: .profile,
            drawerOverlay: .full,
            profileState: .placeholder,
            requestState: .placeholder,
            sendState: .placeholder,
            scanState: .placeholder,
            synchronizerStatusSnapshot: .default,
            totalBalance: Zatoshi.zero,
            walletEventsState: .emptyPlaceHolder,
            verifiedBalance: Zatoshi.zero
        )
        
        let store = TestStore(
            initialState: homeState,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.profile(.settings(.quickRescan))) { state in
            state.route = nil
        }
    }
    
    func testFullRescan_ResetToHomeScreen() throws {
        // setup the store and environment to be fully mocked
        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: MockWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )
        
        let homeState = HomeState(
            route: .profile,
            drawerOverlay: .full,
            profileState: .placeholder,
            requestState: .placeholder,
            sendState: .placeholder,
            scanState: .placeholder,
            synchronizerStatusSnapshot: .default,
            totalBalance: Zatoshi.zero,
            walletEventsState: .emptyPlaceHolder,
            verifiedBalance: Zatoshi.zero
        )
        
        let store = TestStore(
            initialState: homeState,
            reducer: HomeReducer.default,
            environment: testEnvironment
        )
        
        store.send(.profile(.settings(.fullRescan))) { state in
            state.route = nil
        }
    }
}
