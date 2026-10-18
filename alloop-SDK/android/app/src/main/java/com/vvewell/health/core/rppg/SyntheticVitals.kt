package com.vvewell.health.core.rppg

import kotlin.random.Random

/** Debug-only demo values kept separate from measured HR/RR metrics. */
data class SyntheticVitals(
    val demoSpO2: Int,
    val demoStressStatus: SyntheticStressStatus,
)

enum class SyntheticStressStatus(val displayName: String) {
    Normal("正常"),
    Elevated("压力偏大"),
}

internal class SyntheticVitalsFactory(
    private val enabled: Boolean,
    private val nextInt: (until: Int) -> Int = Random.Default::nextInt,
) {
    fun create(): SyntheticVitals? {
        if (!enabled) return null
        return SyntheticVitals(
            demoSpO2 = MIN_SPO2 + nextInt(SPO2_VALUE_COUNT),
            demoStressStatus = if (nextInt(PERCENT_SCALE) < NORMAL_STRESS_PERCENT) {
                SyntheticStressStatus.Normal
            } else {
                SyntheticStressStatus.Elevated
            },
        )
    }

    private companion object {
        const val MIN_SPO2 = 96
        const val SPO2_VALUE_COUNT = 4
        const val PERCENT_SCALE = 100
        const val NORMAL_STRESS_PERCENT = 80
    }
}
