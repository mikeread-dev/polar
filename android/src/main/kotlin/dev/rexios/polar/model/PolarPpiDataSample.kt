package dev.rexios.polar.model

import java.time.LocalTime
import java.util.*

/**
 * Represents a sample of Pulse-to-Pulse Interval (PPi) data.
 */
class PolarPpiDataSample(
    val startTime: LocalTime,
    val triggerType: PPiSampleTriggerType,
    val ppiValueList: List<Int>,
    val ppiErrorEstimateList: List<Int>,
    val statusList: List<PPiSampleStatus>
) {
    /**
     * Creates a new instance of [PolarPpiDataSample] with empty lists.
     */
    constructor(
        startTime: LocalTime,
        triggerType: PPiSampleTriggerType
    ) : this(
        startTime,
        triggerType,
        emptyList(),
        emptyList(),
        emptyList()
    )
} 