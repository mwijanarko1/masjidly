package com.mikhailspeaks.masjidly.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ClosestMosquePromptDecisionTest {
    @Test
    fun presentsOnlyForANewDifferentClosestMosque() {
        assertTrue(
            ClosestMosquePromptDecision.shouldPresent(
                closestMosqueId = "closest",
                selectedMosqueId = "selected",
                dismissedClosestMosqueId = null,
                visibleMosqueCount = 2,
            ),
        )
        assertFalse(
            ClosestMosquePromptDecision.shouldPresent(
                closestMosqueId = "closest",
                selectedMosqueId = "selected",
                dismissedClosestMosqueId = "closest",
                visibleMosqueCount = 2,
            ),
        )
        assertFalse(
            ClosestMosquePromptDecision.shouldPresent(
                closestMosqueId = "selected",
                selectedMosqueId = "selected",
                dismissedClosestMosqueId = null,
                visibleMosqueCount = 2,
            ),
        )
    }
}
