//
//  URIParser.swift
//  secant-testnet
//
//  Created by Lukáš Korba on 17.05.2022.
//

import Foundation

struct URIParser {
    enum URIParserError: Error {
    }
    
    private let derivationTool: WrappedDerivationTool
    
    init(derivationTool: WrappedDerivationTool) {
        self.derivationTool = derivationTool
    }

    func isValidURI(_ uri: String) throws -> Bool {
        try derivationTool.isValidZcashAddress(uri)
    }
}
