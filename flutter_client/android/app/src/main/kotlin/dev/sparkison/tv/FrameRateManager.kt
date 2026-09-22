package dev.sparkison.tv

import android.app.Activity
import android.content.Context
import android.os.Build
import android.util.Log
import android.view.Display
import android.view.WindowManager

/**
 * Applies Auto Frame Rate display-mode matching on Android TV (issue #283):
 * switches the Activity window's preferred display mode to one presenting
 * the source's frame rate cleanly, and restores it when playback stops.
 *
 * Opt-in, off by default -- gated by `PlaybackSource.matchDisplayRefreshRate`
 * (mirrors `ViewSettingsService.matchRefreshRate`, surfaced in Settings next
 * to the existing Windows toggle). This mirrors the open-source Plezy
 * player's own Android setting, `matchContentFrameRate` (also off by
 * default) -- Plezy does not force this on Android, so neither does this app.
 * (tvOS's `AVDisplayManager.preferredDisplayCriteria` use in
 * `tvos/Runner/MpvPlayer/MpvPlayerCore.swift` stays unconditional/unchanged:
 * Plezy's own tvOS core has no equivalent toggle either, so there is nothing
 * to surface for that platform.)
 *
 * One instance is shared by both playback plugins (Media3 and mpv), passed
 * in from `MainActivity`: a `Window`'s `preferredDisplayModeId` is inherently
 * single-owner per Activity, so two independent writers racing during a
 * backend fallback handoff would be unsafe. Sharing is safe because the two
 * plugins never render video concurrently -- `PlaybackOrchestrator` fully
 * releases one native view before loading the next backend.
 *
 * Ported and scoped down from the open-source Plezy player's
 * `FrameRateManager` (github.com/edde746/plezy, GPL-3.0,
 * android/.../shared/FrameRateManager.kt): no `DisplayManager.DisplayListener`
 * settle/watchdog confirmation and no HDR-exit sequencing or
 * `Surface.setFrameRate` hinting in v1 -- nothing here awaits the switch
 * landing (unlike Plezy, no caller pauses playback around it), so that
 * machinery would be diagnostic-only complexity with no functional consumer.
 * Left as documented follow-up work if a real report needs it.
 */
class FrameRateManager(private val activity: Activity) {
    private var applied = false

    /** Applies the best available display mode for [fps], if any and if different from the current mode. */
    fun applyForFrameRate(fps: Double) {
        if (fps <= 0.0 || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val display = currentDisplay() ?: return
        val supportedModes = display.supportedModes ?: return
        val currentMode = display.mode ?: return

        val candidates = supportedModes.map {
            DisplayModeSelector.Mode(it.modeId, it.refreshRate.toDouble(), it.physicalWidth, it.physicalHeight)
        }
        val target = DisplayModeSelector.bestMode(candidates, currentMode.modeId, fps) ?: return
        if (target.modeId == currentMode.modeId) return

        val window = activity.window ?: return
        Log.d(TAG, "matching ${fps}fps: mode #${currentMode.modeId} (${currentMode.refreshRate}Hz) -> #${target.modeId} (${target.refreshRate}Hz)")
        window.attributes = window.attributes.apply { preferredDisplayModeId = target.modeId }
        applied = true
    }

    /** Restores the system's default display mode. Safe to call even if nothing was ever applied. */
    fun restore() {
        if (!applied) return
        applied = false
        val window = activity.window ?: return
        if (window.attributes.preferredDisplayModeId == 0) return
        Log.d(TAG, "restoring default display mode")
        window.attributes = window.attributes.apply { preferredDisplayModeId = 0 }
    }

    private fun currentDisplay(): Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        activity.display
    } else {
        @Suppress("DEPRECATION")
        (activity.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)?.defaultDisplay
    }

    companion object {
        private const val TAG = "FrameRateManager"
    }
}
