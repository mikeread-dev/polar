package dev.rexios.polar.model

/**
 * Represents the status of a PPi sample.
 */
class PPiSampleStatus(
    val skinContact: SkinContact,
    val movement: Movement,
    val intervalStatus: IntervalStatus
) {
    /**
     * Represents the skin contact status.
     */
    enum class SkinContact {
        SKIN_CONTACT_UNDEFINED,
        SKIN_CONTACT_OK,
        SKIN_CONTACT_NOT_OK
    }

    /**
     * Represents the movement status.
     */
    enum class Movement {
        MOVEMENT_UNDEFINED,
        MOVEMENT_OK,
        MOVEMENT_NOT_OK
    }

    /**
     * Represents the interval status.
     */
    enum class IntervalStatus {
        INTERVAL_STATUS_UNDEFINED,
        INTERVAL_STATUS_VALID,
        INTERVAL_STATUS_INVALID
    }
} 