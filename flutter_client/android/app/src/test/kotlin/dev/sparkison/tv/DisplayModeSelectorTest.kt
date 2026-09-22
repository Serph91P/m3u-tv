package dev.sparkison.tv

import dev.sparkison.tv.DisplayModeSelector.Mode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.junit.runners.JUnit4

@RunWith(JUnit4::class)
class DisplayModeSelectorTest {

    private val current = Mode(modeId = 1, refreshRate = 60.0, width = 3840, height = 2160)
    private val sixty = Mode(modeId = 1, refreshRate = 60.0, width = 3840, height = 2160)
    private val fifty = Mode(modeId = 2, refreshRate = 50.0, width = 3840, height = 2160)
    private val oneTwenty = Mode(modeId = 3, refreshRate = 120.0, width = 3840, height = 2160)
    private val twentyFour = Mode(modeId = 4, refreshRate = 24.0, width = 3840, height = 2160)
    private val otherResolution1080p60 = Mode(modeId = 5, refreshRate = 60.0, width = 1920, height = 1080)

    @Test
    fun picksExactMatchOverAMultiple() {
        val candidates = listOf(sixty, twentyFour, oneTwenty)
        val result = DisplayModeSelector.bestMode(candidates, currentModeId = 1, targetFps = 24.0)
        assertEquals(twentyFour, result)
    }

    @Test
    fun picksCleanIntegerMultipleForFractionalNtscRate() {
        // 23.976fps is a clean 5:5 on a 120Hz panel (5 * 23.976 = 119.88).
        val candidates = listOf(sixty, oneTwenty)
        val result = DisplayModeSelector.bestMode(candidates, currentModeId = 1, targetFps = 23.976)
        assertEquals(oneTwenty, result)
    }

    @Test
    fun prefersLargerMultipleWhenBothMatchCleanly() {
        // 24fps: 48Hz (2x) and 120Hz (5x) are both clean multiples -- prefer the larger.
        val fortyEight = Mode(modeId = 6, refreshRate = 48.0, width = 3840, height = 2160)
        val candidates = listOf(sixty, fortyEight, oneTwenty)
        val result = DisplayModeSelector.bestMode(candidates, currentModeId = 1, targetFps = 24.0)
        assertEquals(oneTwenty, result)
    }

    @Test
    fun returnsNullWhenNoCandidateIsWithinTolerance() {
        // 23.976fps against a 50/60Hz-only set: neither is an exact match nor a clean multiple.
        val candidates = listOf(sixty, fifty)
        val result = DisplayModeSelector.bestMode(candidates, currentModeId = 1, targetFps = 23.976)
        assertNull(result)
    }

    @Test
    fun ignoresModesAtADifferentResolution() {
        val candidates = listOf(sixty, otherResolution1080p60, twentyFour)
        val result = DisplayModeSelector.bestMode(candidates, currentModeId = 1, targetFps = 24.0)
        assertEquals(twentyFour, result)
    }

    @Test
    fun returnsNullForNonPositiveTargetFps() {
        assertNull(DisplayModeSelector.bestMode(listOf(sixty, twentyFour), currentModeId = 1, targetFps = 0.0))
        assertNull(DisplayModeSelector.bestMode(listOf(sixty, twentyFour), currentModeId = 1, targetFps = -24.0))
    }

    @Test
    fun returnsNullWhenCurrentModeIdIsNotAmongCandidates() {
        val result = DisplayModeSelector.bestMode(listOf(sixty, twentyFour), currentModeId = 99, targetFps = 24.0)
        assertNull(result)
    }
}
