package dev.rexios.polar.model

/**
 * Represents the trigger type for PPi samples.
 */
enum class PPiSampleTriggerType(val value: Int) {
    /**
     * Undefined trigger type
     */
    TRIGGER_TYPE_UNDEFINED(0),

    /**
     * Automatic recording (for example 24/7 recording)
     */
    TRIGGER_TYPE_AUTOMATIC(1),

    /**
     * Manual recording (started by user)
     */
    TRIGGER_TYPE_MANUAL(2);

    companion object {
        fun fromValue(value: Int): PPiSampleTriggerType {
            return values().find { it.value == value } ?: TRIGGER_TYPE_UNDEFINED
        }
    }
} 