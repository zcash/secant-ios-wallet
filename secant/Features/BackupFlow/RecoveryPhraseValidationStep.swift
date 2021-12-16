//
//  RecoveryPhraseValidationState.RecoveryPhraseValidationStep.swift
//  secant-testnet
//
//  Created by Francisco Gindre on 11/2/21.
//

import Foundation


/// Represents the completion of a group of recovery words by de addition of one word into the given group
struct RecoveryPhraseStepCompletion: Equatable {
    var groupIndex: Int
    var word: String
}

extension RecoveryPhrase.Chunk {
    func words(with missingIndex: Int) -> [String] {
        var wordsApplyingMissing = self.words
        wordsApplyingMissing[missingIndex] = ""
        return wordsApplyingMissing
    }
}
