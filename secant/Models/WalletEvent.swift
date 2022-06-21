//
//  WalletEvent.swift
//  secant-testnet
//
//  Created by Lukáš Korba on 20.06.2022.
//

import Foundation
import ComposableArchitecture
import SwiftUI
import ZcashLightClientKit

// MARK: - Model

struct WalletEvent: Equatable, Identifiable {
    enum WalletEventState: Equatable {
        case send(TransactionState)
        case pending(TransactionState)
        case received(TransactionState)
        case failed(TransactionState)
        case shielded(Zatoshi)
        case walletImport(BlockHeight)
    }
    
    let id: String
    let state: WalletEventState
    var timestamp: TimeInterval
}

// MARK: - Rows

extension WalletEvent {
    @ViewBuilder func rowView() -> some View {
        switch state {
        case .send(let transaction):
            TransactionRowView(transaction: transaction)
        case .pending:
            Text("pending wallet event")
        case .received:
            Text("received wallet event")
        case .failed:
            Text("failed wallet event")
        case .shielded(let zatoshi):
            Text("shielded wallet event \(zatoshi.decimalString())")
        case .walletImport:
            Text("wallet import wallet event")
        }
    }
}

// MARK: - Details

extension WalletEvent {
    @ViewBuilder func detailView() -> some View {
        switch state {
        case .send(let transaction):
            TransactionDetailView(transaction: transaction)
        case .pending:
            Text("pending transaction detail")
        case .received:
            Text("received transaction detail")
        case .failed:
            Text("failed transaction detail")
        case .shielded(let zatoshi):
            Text("shielded \(zatoshi.decimalString()) detail")
        case .walletImport:
            Text("wallet import wallet event")
        }
    }
}

// MARK: - Placeholders

private extension WalletEvent {
    static func randomWalletEventState() -> WalletEvent.WalletEventState {
        switch Int.random(in: 0..<5) {
        case 1: return .received(.placeholder)
        case 2: return .failed(.placeholder)
        case 3: return .shielded(Zatoshi(amount: 234_000_000))
        case 4: return .walletImport(BlockHeight(1_629_724))
        default: return .send(.placeholder)
        }
    }
}

extension IdentifiedArrayOf where Element == WalletEvent {
    static var placeholder: IdentifiedArrayOf<WalletEvent> {
        return .init(
            uniqueElements: (0..<30).map {
                WalletEvent(
                    id: String($0),
                    state: WalletEvent.randomWalletEventState(),
                    timestamp: 1234567
                )
            }
        )
    }
}
