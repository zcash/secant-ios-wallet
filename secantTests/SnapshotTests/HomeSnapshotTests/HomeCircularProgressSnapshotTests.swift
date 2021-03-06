//
//  HomeCircularProgressSnapshotTests.swift
//  secantTests
//
//  Created by Lukáš Korba on 07.07.2022.
//

import XCTest
import ComposableArchitecture
@testable import secant_testnet
@testable import ZcashLightClientKit

class HomeCircularProgressSnapshotTests: XCTestCase {
    func testCircularProgress_DownloadingInnerCircle() throws {
        class SnapshotTestWrappedSDKSynchronizer: TestWrappedSDKSynchronizer {
            // heights purposely set so we visually see 55% progress
            override func statusSnapshot() -> SyncStatusSnapshot {
                let blockProgress = BlockProgress(
                    startHeight: BlockHeight(0),
                    targetHeight: BlockHeight(100),
                    progressHeight: BlockHeight(55)
                )
                
                return SyncStatusSnapshot.snapshotFor(state: .downloading(blockProgress))
            }
        }

        let balance = WalletBalance(verified: Zatoshi(15_345_000), total: Zatoshi(15_345_000))

        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: SnapshotTestWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )

        let store = HomeStore(
            initialState: .init(
                drawerOverlay: .partial,
                profileState: .placeholder,
                requestState: .placeholder,
                sendState: .placeholder,
                scanState: .placeholder,
                synchronizerStatusSnapshot: .default,
                totalBalance: balance.total,
                walletEventsState: .emptyPlaceHolder,
                verifiedBalance: balance.verified
            ),
            reducer: .default,
            environment: testEnvironment
        )

        addAttachments(HomeView(store: store))
    }
    
    func testCircularProgress_ScanningOuterCircle() throws {
        class SnapshotTestWrappedSDKSynchronizer: TestWrappedSDKSynchronizer {
            override func statusSnapshot() -> SyncStatusSnapshot {
                // heights purposely set so we visually see 72% progress
                let blockProgress = BlockProgress(
                    startHeight: BlockHeight(0),
                    targetHeight: BlockHeight(100),
                    progressHeight: BlockHeight(72)
                )
                
                return SyncStatusSnapshot.snapshotFor(state: .scanning(blockProgress))
            }
        }

        let balance = WalletBalance(verified: 15_345_000, total: 15_345_000)

        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: SnapshotTestWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )

        let store = HomeStore(
            initialState: .init(
                drawerOverlay: .partial,
                profileState: .placeholder,
                requestState: .placeholder,
                sendState: .placeholder,
                scanState: .placeholder,
                synchronizerStatusSnapshot: .default,
                totalBalance: balance.total,
                walletEventsState: .emptyPlaceHolder,
                verifiedBalance: balance.verified
            ),
            reducer: .default,
            environment: testEnvironment
        )

        addAttachments(HomeView(store: store))
    }
    
    func testCircularProgress_UpToDateOnlyOuterCircle() throws {
        class SnapshotTestWrappedSDKSynchronizer: TestWrappedSDKSynchronizer {
            override func statusSnapshot() -> SyncStatusSnapshot {
                SyncStatusSnapshot.snapshotFor(state: .synced)
            }
        }

        let balance = WalletBalance(verified: 15_345_000, total: 15_345_000)

        let testScheduler = DispatchQueue.test

        let testEnvironment = HomeEnvironment(
            audioServices: .silent,
            derivationTool: .live(),
            feedbackGenerator: .silent,
            mnemonic: .mock,
            scheduler: testScheduler.eraseToAnyScheduler(),
            SDKSynchronizer: SnapshotTestWrappedSDKSynchronizer(),
            walletStorage: .throwing,
            zcashSDKEnvironment: .testnet
        )

        let store = HomeStore(
            initialState: .init(
                drawerOverlay: .partial,
                profileState: .placeholder,
                requestState: .placeholder,
                sendState: .placeholder,
                scanState: .placeholder,
                synchronizerStatusSnapshot: .default,
                totalBalance: balance.total,
                walletEventsState: .emptyPlaceHolder,
                verifiedBalance: balance.verified
            ),
            reducer: .default,
            environment: testEnvironment
        )

        addAttachments(HomeView(store: store))
    }
}
