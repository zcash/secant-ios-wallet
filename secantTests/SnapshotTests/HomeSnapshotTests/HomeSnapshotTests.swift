//
//  HomeSnapshotTests.swift
//  secantTests
//
//  Created by Lukáš Korba on 13.06.2022.
//

import XCTest
@testable import secant_testnet
import ComposableArchitecture

class HomeSnapshotTests: XCTestCase {
    func testHomeSnapshot() throws {
        let transactionsHelper: [TransactionStateMockHelper] = [
            TransactionStateMockHelper(date: 1651039202, amount: Zatoshi(amount: 1), status: .paid(success: true), uuid: "1"),
            TransactionStateMockHelper(date: 1651039101, amount: Zatoshi(amount: 2), status: .pending, uuid: "2"),
            TransactionStateMockHelper(date: 1651039000, amount: Zatoshi(amount: 3), status: .received, uuid: "3"),
            TransactionStateMockHelper(date: 1651039505, amount: Zatoshi(amount: 4), status: .failed, uuid: "4")
        ]
        
        let walletEvents: [WalletEvent] = transactionsHelper.map {
            var transaction = TransactionState.placeholder(
                amount: $0.amount,
                fee: Zatoshi(amount: 10),
                shielded: $0.shielded,
                status: $0.status,
                timestamp: $0.date,
                uuid: $0.uuid
            )
            transaction.zAddress = "t1gXqfSSQt6WfpwyuCU3Wi7sSVZ66DYQ3Po"
            
            return WalletEvent(id: transaction.id, state: .send(transaction), timestamp: transaction.timestamp)
        }
        
        let balance = Balance(verified: 12_345_000, total: 12_345_000)

        let store = HomeStore(
            initialState: .init(
                drawerOverlay: .partial,
                profileState: .placeholder,
                requestState: .placeholder,
                sendState: .placeholder,
                scanState: .placeholder,
                synchronizerStatusSnapshot: .default,
                totalBalance: Zatoshi(amount: balance.total),
                walletEventsState: .init(walletEvents: IdentifiedArrayOf(uniqueElements: walletEvents)),
                verifiedBalance: Zatoshi(amount: balance.verified)
            ),
            reducer: .default,
            environment: .demo
        )

        // landing home screen
        addAttachments(HomeView(store: store))
    }
}
