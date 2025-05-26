package dev.rexios.polar.model

import java.util.*

/**
 * Represents 24/7 Peak-to-peak interval data samples from a Polar device.
 */
class Polar247PPiSamplesData(
    val date: Date,
    val samples: PolarPpiDataSample
) 