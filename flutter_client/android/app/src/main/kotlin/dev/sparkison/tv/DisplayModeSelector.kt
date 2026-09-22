package dev.sparkison.tv

import kotlin.math.abs
import kotlin.math.round

/**
 * Pure display-mode selection for Auto Frame Rate matching (issue #283),
 * extracted from [FrameRateManager] so it's testable on the plain JVM --
 * `android.view.Display` can't be instantiated in a JVM unit test, mirroring
 * how `ResumeStallPolicy` keeps its decision logic free of Media3 types.
 *
 * Ported and scoped down from the open-source Plezy player's
 * `DisplayModeSelector` (github.com/edde746/plezy, GPL-3.0,
 * android/.../shared/DisplayModeSelector.kt): this matches refresh rate only,
 * at the current resolution only, with no resolution-switching or
 * pulldown-cadence fallback tier -- the same scope
 * `windows/runner/mpv/display_mode_manager.h`'s `MatchRefreshRate` already
 * uses for Windows.
 */
internal object DisplayModeSelector {
    /** Hz tolerance for an exact-rate match, before scaling for a multiple. */
    private const val RATE_TOLERANCE = 0.1

    /** Largest clean multiple worth switching for (5x 23.976 = 119.88, just under a 120Hz panel). */
    private const val MAX_MULTIPLE = 5

    data class Mode(val modeId: Int, val refreshRate: Double, val width: Int, val height: Int)

    private data class RateMatch(val priority: Int, val error: Double, val multiple: Int)

    /**
     * The best mode among [candidates] presenting [targetFps] cleanly, or null
     * if none does within tolerance (or [currentModeId] isn't among
     * [candidates]). Only modes at the same resolution as [currentModeId] are
     * considered -- Android's seamless `preferredDisplayModeId` switch only
     * guarantees a glitch-free transition within one resolution class.
     */
    fun bestMode(candidates: List<Mode>, currentModeId: Int, targetFps: Double): Mode? {
        if (targetFps <= 0.0) return null
        val current = candidates.firstOrNull { it.modeId == currentModeId } ?: return null
        val sameResolution = candidates.filter { it.width == current.width && it.height == current.height }

        return sameResolution
            .mapNotNull { mode -> matchError(mode.refreshRate, targetFps)?.let { mode to it } }
            .minWithOrNull(
                compareBy<Pair<Mode, RateMatch>> { it.second.priority }
                    .thenBy { it.second.error }
                    .thenByDescending { it.second.multiple },
            )
            ?.first
    }

    /** How well [refreshRate] presents [targetFps]: exact (priority 0), an integer multiple (priority 1), or neither. */
    private fun matchError(refreshRate: Double, targetFps: Double): RateMatch? {
        if (refreshRate <= 0.0) return null
        val exactError = abs(refreshRate - targetFps)
        if (exactError < RATE_TOLERANCE) return RateMatch(priority = 0, error = exactError, multiple = 1)

        // The error is measured after multiplication, so the tolerance scales
        // with the multiple -- a flat 0.1Hz would reject |120 - 5*23.976| =
        // 0.12, which is exactly the clean 5:5 case a 120Hz panel should match.
        val multiple = round(refreshRate / targetFps).toInt()
        if (multiple in 2..MAX_MULTIPLE) {
            val multipleError = abs(refreshRate - targetFps * multiple)
            if (multipleError < RATE_TOLERANCE * multiple) {
                return RateMatch(priority = 1, error = multipleError, multiple = multiple)
            }
        }
        return null
    }
}
