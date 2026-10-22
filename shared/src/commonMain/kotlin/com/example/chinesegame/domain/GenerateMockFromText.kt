package com.example.chinesegame.domain

import com.example.chinesegame.model.MockComponent
import com.example.chinesegame.model.Term

// Stub for v1.1 capture-to-generate. Pure logic, unit-tested, unused in v1 UI.
class GenerateMockFromText {
    fun invoke(ocrText: String, knownTerms: List<Term>, domainId: String): List<MockComponent> =
        knownTerms
            .filter { it.domainId == domainId && ocrText.contains(it.zh) }
            .map { MockComponent("button", it.zh, it.domainId) }
}
