package dev.rexios.polar

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.lifecycle.Lifecycle.Event
import androidx.lifecycle.LifecycleEventObserver
import com.google.gson.GsonBuilder
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonPrimitive
import com.google.gson.JsonSerializationContext
import com.google.gson.JsonSerializer
import com.google.gson.JsonSyntaxException
import com.polar.androidcommunications.api.ble.model.DisInfo
import com.polar.sdk.api.PolarBleApi
import com.polar.sdk.api.PolarBleApi.PolarBleSdkFeature
import com.polar.sdk.api.PolarBleApi.PolarDeviceDataType
import com.polar.sdk.api.PolarBleApiCallbackProvider
import com.polar.sdk.api.PolarBleApiDefaultImpl
import com.polar.sdk.api.PolarH10OfflineExerciseApi.RecordingInterval
import com.polar.sdk.api.PolarH10OfflineExerciseApi.SampleType
import com.polar.sdk.api.model.LedConfig
import com.polar.sdk.api.model.PolarDeviceInfo
import com.polar.sdk.api.model.PolarExerciseEntry
import com.polar.sdk.api.model.PolarFirstTimeUseConfig
import com.polar.sdk.api.model.PolarHealthThermometerData
import com.polar.sdk.api.model.PolarHrData
import com.polar.sdk.api.model.PolarSensorSetting
import com.polar.sdk.api.model.PolarOfflineRecordingEntry
import com.polar.sdk.api.model.PolarOfflineRecordingTrigger
import com.polar.sdk.api.model.PolarOfflineRecordingTriggerMode
import com.polar.sdk.api.model.PolarRecordingSecret
import com.polar.sdk.api.model.sleep.PolarSleepData
import com.polar.sdk.api.model.FirmwareUpdateStatus
import com.polar.androidcommunications.api.ble.model.gatt.client.ChargeState
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.lifecycle.FlutterLifecycleAdapter
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.reactivex.rxjava3.disposables.Disposable
import io.reactivex.rxjava3.core.Completable
import java.lang.reflect.Type
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.time.LocalDate
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.Calendar
import java.util.TimeZone
import com.polar.sdk.api.errors.PolarDeviceDisconnected
import com.polar.sdk.api.errors.PolarOperationNotSupported
import io.reactivex.rxjava3.plugins.RxJavaPlugins
import io.reactivex.rxjava3.exceptions.OnErrorNotImplementedException

fun Any?.discard() = Unit

object DateSerializer : JsonDeserializer<Date>, JsonSerializer<Date> {
    override fun deserialize(
        json: JsonElement?,
        typeOfT: Type?,
        context: JsonDeserializationContext?,
    ): Date = Date(json?.asJsonPrimitive?.asLong ?: 0)

    override fun serialize(
        src: Date?,
        typeOfSrc: Type?,
        context: JsonSerializationContext?,
    ): JsonElement = JsonPrimitive(src?.time)
}

private fun runOnUiThread(runnable: () -> Unit) {
    Handler(Looper.getMainLooper()).post { runnable() }
}

private val gson = GsonBuilder().registerTypeAdapter(Date::class.java, DateSerializer).create()

private var wrapperInternal: PolarWrapper? = null
private val wrapper: PolarWrapper
    get() = wrapperInternal!!

// Add these constants at the top of the file
private object PolarErrorCode {
    const val DEVICE_DISCONNECTED = "device_disconnected"
    const val NOT_SUPPORTED = "not_supported"
    const val INVALID_ARGUMENT = "invalid_argument"
    const val OPERATION_NOT_ALLOWED = "operation_not_allowed"
    const val TIMEOUT = "timeout"
    const val BLUETOOTH_ERROR = "bluetooth_error"
}

/** PolarPlugin */
class PolarPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    // Binary messenger for dynamic EventChannel registration
    private lateinit var messenger: BinaryMessenger

    // Method channel
    private lateinit var channel: MethodChannel

    // Search channel
    private lateinit var searchChannel: EventChannel

    // Firmware update channel
    private lateinit var firmwareUpdateChannel: EventChannel

    // Context
    private lateinit var context: Context

    // Streaming channels
    private val streamingChannels = mutableMapOf<String, StreamingChannel>()

    // Add a companion object to the PolarPlugin class with a TAG constant
    companion object {
        private const val TAG = "PolarPlugin"
    }
    
    // Apparently you have to call invokeMethod on the UI thread
    private fun invokeOnUiThread(
        method: String,
        arguments: Any?,
        callback: Result? = null,
    ) {
        runOnUiThread { channel.invokeMethod(method, arguments, callback) }
    }

    private val polarCallback = { method: String, arguments: Any? ->
        invokeOnUiThread(method, arguments)
    }

    // Add this method to set up RxJava error handling
    private fun setupRxErrorHandling() {
        // This prevents RxJava from crashing the app when errors aren't handled
        RxJavaPlugins.setErrorHandler { e: Throwable ->
            when {
                e is OnErrorNotImplementedException && e.cause?.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> {
                    // This is the specific error we're seeing
                    println("[PolarPlugin] Safely caught NO_SUCH_FILE_OR_DIRECTORY exception: ${e.cause?.message}")
                }
                e is OnErrorNotImplementedException -> {
                    println("[PolarPlugin] Caught undeliverable RxJava exception: ${e.cause?.message ?: e.message}")
                }
                else -> {
                    println("[PolarPlugin] Caught RxJava error: ${e.message}")
                }
            }
            // Don't propagate the error - this prevents crashes
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        messenger = flutterPluginBinding.binaryMessenger

        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "polar")
        channel.setMethodCallHandler(this)

        searchChannel = EventChannel(flutterPluginBinding.binaryMessenger, "polar/search")
        searchChannel.setStreamHandler(searchHandler)
        
        firmwareUpdateChannel = EventChannel(flutterPluginBinding.binaryMessenger, "polar/firmware_update")
        firmwareUpdateChannel.setStreamHandler(firmwareUpdateHandler)

        context = flutterPluginBinding.applicationContext
        
        // Set up RxJava error handling
        setupRxErrorHandling()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        searchChannel.setStreamHandler(null)
        streamingChannels.values.forEach { it.dispose() }
        shutDown()
    }

    private fun initApi() {
        if (wrapperInternal == null) {
            wrapperInternal = PolarWrapper(context)
        }
        wrapper.addCallback(polarCallback)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        initApi()

        when (call.method) {
            "connectToDevice" -> {
                wrapper.api.connectToDevice(call.arguments as String)
                result.success(null)
            }

            "disconnectFromDevice" -> {
                wrapper.api.disconnectFromDevice(call.arguments as String)
                result.success(null)
            }

            "getAvailableOnlineStreamDataTypes" -> getAvailableOnlineStreamDataTypes(call, result)
            "requestStreamSettings" -> requestStreamSettings(call, result)
            "createStreamingChannel" -> createStreamingChannel(call, result)
            "startRecording" -> startRecording(call, result)
            "stopRecording" -> stopRecording(call, result)
            "requestRecordingStatus" -> requestRecordingStatus(call, result)
            "listExercises" -> listExercises(call, result)
            "fetchExercise" -> fetchExercise(call, result)
            "removeExercise" -> removeExercise(call, result)
            "setLedConfig" -> setLedConfig(call, result)
            "doFactoryReset" -> doFactoryReset(call, result)
            "enableSdkMode" -> enableSdkMode(call, result)
            "disableSdkMode" -> disableSdkMode(call, result)
            "isSdkModeEnabled" -> isSdkModeEnabled(call, result)
            "getAvailableOfflineRecordingDataTypes" -> getAvailableOfflineRecordingDataTypes(
                call,
                result
            )

            "requestOfflineRecordingSettings" -> requestOfflineRecordingSettings(call, result)
            "startOfflineRecording" -> startOfflineRecording(call, result)
            "stopOfflineRecording" -> stopOfflineRecording(call, result)
            "getOfflineRecordingStatus" -> getOfflineRecordingStatus(call, result)
            "listOfflineRecordings" -> listOfflineRecordings(call, result)
            "getOfflineRecord" -> getOfflineRecord(call, result)
            "removeOfflineRecord" -> removeOfflineRecord(call, result)
            "getDiskSpace" -> getDiskSpace(call, result)
            "getLocalTime" -> getLocalTime(call, result)
            "setLocalTime" -> setLocalTime(call, result)
            "doFirstTimeUse" -> doFirstTimeUse(call, result)
            "isFtuDone" -> isFtuDone(call, result)
            "getSleep" -> getSleep(call, result)
            "stopSleepRecording" -> stopSleepRecording(call, result)
            "getSleepRecordingState" -> getSleepRecordingState(call, result)
            "setupSleepStateObservation" -> setupSleepStateObservation(call, result)
            "get247PPiSamples" -> get247PPiSamples(call, result)
            "deleteDeviceDateFolders" -> deleteDeviceDateFolders(call, result)
            "deleteStoredDeviceData" -> deleteStoredDeviceData(call, result)
            "setOfflineRecordingTrigger" -> setOfflineRecordingTrigger(call, result)
            "doRestart" -> doRestart(call, result)
            "updateFirmware" -> updateFirmware(call, result)
            else -> result.notImplemented()
        }
    }

    private val searchHandler =
        object : EventChannel.StreamHandler {
            private var searchSubscription: Disposable? = null

            override fun onListen(
                arguments: Any?,
                events: EventSink,
            ) {
                initApi()

                searchSubscription =
                    wrapper.api.searchForDevice().subscribe({
                        runOnUiThread { events.success(gson.toJson(it)) }
                    }, {
                        runOnUiThread {
                            events.error(it.toString(), it.message, null)
                        }
                    }, {
                        runOnUiThread { events.endOfStream() }
                    })
            }

            override fun onCancel(arguments: Any?) {
                searchSubscription?.dispose()
            }
        }

    private var firmwareUpdateEvents: EventSink? = null
    private var firmwareUpdateSubscription: Disposable? = null

    private val firmwareUpdateHandler =
        object : EventChannel.StreamHandler {
            override fun onListen(
                arguments: Any?,
                events: EventSink,
            ) {
                firmwareUpdateEvents = events
            }

            override fun onCancel(arguments: Any?) {
                firmwareUpdateSubscription?.dispose()
                firmwareUpdateEvents = null
            }
        }

    private fun createStreamingChannel(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val name = arguments[0] as String
        val identifier = arguments[1] as String
        val feature = gson.fromJson(arguments[2] as String, PolarDeviceDataType::class.java)

        if (streamingChannels[name] == null) {
            streamingChannels[name] =
                StreamingChannel(messenger, name, wrapper.api, identifier, feature)
        }

        result.success(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        val lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(binding)
        lifecycle.addObserver(
            LifecycleEventObserver { _, event ->
                when (event) {
                    Event.ON_RESUME -> wrapperInternal?.api?.foregroundEntered()
                    Event.ON_DESTROY -> shutDown()
                    else -> {}
                }
            },
        )
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}

    override fun onDetachedFromActivity() {}

    private fun shutDown() {
        if (wrapperInternal == null) return
        wrapper.removeCallback(polarCallback)
        wrapper.shutDown()
    }

    private fun getAvailableOnlineStreamDataTypes(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        wrapper.api
            .getAvailableOnlineStreamDataTypes(identifier)
            .subscribe({
                runOnUiThread { result.success(gson.toJson(it)) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun requestStreamSettings(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val feature = gson.fromJson(arguments[1] as String, PolarDeviceDataType::class.java)

        wrapper.api
            .requestStreamSettings(identifier, feature)
            .subscribe({
                runOnUiThread { result.success(gson.toJson(it)) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun startRecording(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val exerciseId = arguments[1] as String
        val interval = gson.fromJson(arguments[2] as String, RecordingInterval::class.java)
        val sampleType = gson.fromJson(arguments[3] as String, SampleType::class.java)

        wrapper.api
            .startRecording(identifier, exerciseId, interval, sampleType)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun stopRecording(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        wrapper.api
            .stopRecording(identifier)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun requestRecordingStatus(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        wrapper.api
            .requestRecordingStatus(identifier)
            .subscribe({
                runOnUiThread { result.success(listOf(it.first, it.second)) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun listExercises(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        val exercises = mutableListOf<String>()
        wrapper.api
            .listExercises(identifier)
            .subscribe({
                exercises.add(gson.toJson(it))
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            }, {
                result.success(exercises)
            })
            .discard()
    }

    private fun fetchExercise(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val entry = gson.fromJson(arguments[1] as String, PolarExerciseEntry::class.java)

        wrapper.api
            .fetchExercise(identifier, entry)
            .subscribe({
                result.success(gson.toJson(it))
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun removeExercise(
        call: MethodCall,
        result: Result,
    ) {
        try {
            val arguments = call.arguments as? List<*>
            val identifier = arguments?.getOrNull(0) as? String
            val entryJson = arguments?.getOrNull(1) as? String

            if (identifier == null || entryJson == null) {
                result.error(
                    PolarErrorCode.INVALID_ARGUMENT,
                    "Invalid arguments provided",
                    null
                )
                return
            }

            val entry = gson.fromJson(entryJson, PolarExerciseEntry::class.java)
            wrapper.api.removeExercise(identifier, entry)
                .subscribe(
                    { result.success(null) },
                    { error ->
                        val code = when (error) {
                            is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                            is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                            else -> PolarErrorCode.BLUETOOTH_ERROR
                        }
                        result.error(code, error.message, null)
                    }
                )
        } catch (e: JsonSyntaxException) {
            result.error(
                PolarErrorCode.INVALID_ARGUMENT,
                "Failed to decode exercise entry",
                null
            )
        }
    }

    private fun setLedConfig(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val config = gson.fromJson(arguments[1] as String, LedConfig::class.java)

        wrapper.api
            .setLedConfig(identifier, config)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun doFactoryReset(
        call: MethodCall,
        result: Result,
    ) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val preservePairingInformation = arguments[1] as Boolean

        wrapper.api
            .doFactoryReset(identifier, preservePairingInformation)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun enableSdkMode(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String
        wrapper.api
            .enableSDKMode(identifier)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun disableSdkMode(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String
        wrapper.api
            .disableSDKMode(identifier)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun isSdkModeEnabled(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String
        wrapper.api
            .isSDKModeEnabled(identifier)
            .subscribe({
                runOnUiThread { result.success(it) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun getAvailableOfflineRecordingDataTypes(call: MethodCall, result: Result) {
        val identifier = call.arguments as String

        wrapper.api
            .getAvailableOfflineRecordingDataTypes(identifier)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({
                runOnUiThread { result.success(gson.toJson(it)) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun requestOfflineRecordingSettings(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val feature = gson.fromJson(arguments[1] as String, PolarDeviceDataType::class.java)

        wrapper.api
            .requestOfflineRecordingSettings(identifier, feature)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({
                runOnUiThread { result.success(gson.toJson(it)) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun startOfflineRecording(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val feature = gson.fromJson(arguments[1] as String, PolarDeviceDataType::class.java)
        val settings = gson.fromJson(arguments[2] as String, PolarSensorSetting::class.java)

        // Flag to prevent double responses
        var resultSent = false

        try {
            wrapper.api
                .startOfflineRecording(identifier, feature, settings)
                .doOnError { error ->
                    System.err.println("Error in startOfflineRecording: " + error.message)
                }
                .onErrorResumeNext { error ->
                    runOnUiThread {
                        if (!resultSent) {
                            resultSent = true
                            val errorCode = when {
                                error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                                error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                                error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                                error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                                else -> "ERROR_STARTING_RECORDING"
                            }
                            result.error(errorCode, error.message, null)
                        }
                    }
                    Completable.complete() // Return a completed Completable to prevent error propagation
                }
                .subscribe({
                    runOnUiThread { 
                        if (!resultSent) {
                            resultSent = true
                            result.success(null) 
                        }
                    }
                }, { error ->
                    // This should only be called if onErrorResumeNext somehow fails
                    runOnUiThread {
                        if (!resultSent) {
                            resultSent = true
                            System.err.println("Error in subscribe: " + error.message)
                            result.error("UNEXPECTED_ERROR", error.message, null)
                        }
                    }
                })
                .discard()
        } catch (e: Exception) {
            // Catch any exceptions that might occur before the RxJava chain even starts
            val errorCode = when {
                e.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                e is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                e is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                e.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                else -> "ERROR_STARTING_RECORDING"
            }
            
            runOnUiThread {
                if (!resultSent) {
                    resultSent = true
                    System.err.println("Exception before RxJava chain: " + e.message)
                    result.error(errorCode, e.message, null)
                }
            }
        }
    }

    private fun stopOfflineRecording(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val feature = gson.fromJson(arguments[1] as String, PolarDeviceDataType::class.java)

        wrapper.api
            .stopOfflineRecording(identifier, feature)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({
                runOnUiThread { result.success(null) }
            }, { error ->
                runOnUiThread {
                    val errorCode = when {
                        error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> "ERROR_STOPPING_RECORDING"
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }

    private fun getOfflineRecordingStatus(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String

        wrapper.api
            .getOfflineRecordingStatus(identifier)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({ dataTypes ->
                val dataTypeNames = dataTypes.map { it.name }
                runOnUiThread { result.success(dataTypeNames) }
            }, { error ->
                runOnUiThread {
                    val errorCode = when {
                        error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> "ERROR_STOPPING_RECORDING"
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }

    private fun listOfflineRecordings(call: MethodCall, result: Result) {
        val identifier = call.arguments as String

        val recordings = mutableListOf<String>()
        wrapper.api
            .listOfflineRecordings(identifier)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({
                recordings.add(gson.toJson(it))
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            }, {
                result.success(recordings)
            })
            .discard()
    }

    private fun getOfflineRecord(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val entry = gson.fromJson(arguments[1] as String, PolarOfflineRecordingEntry::class.java)

        wrapper.api
            .getOfflineRecord(identifier, entry)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({
                runOnUiThread { result.success(gson.toJson(it)) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    /**
     * Safely removes an offline record, handling NO_SUCH_FILE_OR_DIRECTORY errors gracefully
     * Use this as an alternative to wrapper.api.removeOfflineRecord which can crash
     */
    private fun safeRemoveOfflineRecord(identifier: String, entry: PolarOfflineRecordingEntry): Completable {
        println("[PolarPlugin] Starting safeRemoveOfflineRecord for identifier: $identifier, path: ${entry.path}")
        
        return Completable.create { emitter ->
            // Set up error handling in case the completable itself has issues
            RxJavaPlugins.setErrorHandler { e: Throwable ->
                println("[PolarPlugin] Caught error in safeRemoveOfflineRecord RxJava chain: ${e.message}")
                // Don't propagate the error - prevents app crashes
            }
            
            try {
                val subscription = wrapper.api.removeOfflineRecord(identifier, entry)
                    .doOnError { error ->
                        println("[PolarPlugin] Error in safeRemoveOfflineRecord: ${error.message}")
                    }
                    .subscribe(
                        { // onComplete 
                            println("[PolarPlugin] safeRemoveOfflineRecord completed successfully")
                            if (!emitter.isDisposed) {
                                emitter.onComplete()
                            }
                        },
                        { error -> // onError
                            println("[PolarPlugin] Error in safeRemoveOfflineRecord: ${error.message}")
                            if (error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true) {
                                // If the file doesn't exist, that's fine - consider it removed
                                if (!emitter.isDisposed) {
                                    emitter.onComplete()
                                }
                            } else {
                                // For other errors, propagate them
                                if (!emitter.isDisposed) {
                                    emitter.onError(error)
                                }
                            }
                        }
                    )
                
                // Make sure to dispose the subscription when the emitter is cancelled
                emitter.setCancellable { subscription.dispose() }
            } catch (e: Exception) {
                println("[PolarPlugin] Exception in safeRemoveOfflineRecord: ${e.message}")
                if (!emitter.isDisposed) {
                    emitter.onError(e)
                }
            }
        }
    }

    // Now update the removeOfflineRecord method to use our safer version
    private fun removeOfflineRecord(call: MethodCall, result: Result) {
        try {
            val arguments = call.arguments as? List<*>
            val identifier = arguments?.getOrNull(0) as? String
            val entryJson = arguments?.getOrNull(1) as? String

            if (identifier == null || entryJson == null) {
                result.error(
                    PolarErrorCode.INVALID_ARGUMENT,
                    "Invalid arguments provided",
                    null
                )
                return
            }

            val entry = gson.fromJson(entryJson, PolarOfflineRecordingEntry::class.java)
            
            // Use our safer version instead of calling the API directly
            safeRemoveOfflineRecord(identifier, entry)
                .subscribe(
                    { // onComplete
                        runOnUiThread { result.success(null) }
                    },
                    { error -> // onError
                        runOnUiThread {
                            println("[PolarPlugin] Final error in removeOfflineRecord: ${error.message}")
                            val code = when {
                                error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                                error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                                error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                                error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                                else -> PolarErrorCode.BLUETOOTH_ERROR
                            }
                            result.error(code, error.message, null)
                        }
                    }
                )
                .discard()
        } catch (e: Exception) {
            // Handle any exceptions from parameter extraction or JSON parsing
            println("[PolarPlugin] Exception in removeOfflineRecord setup: ${e.message}")
            e.printStackTrace()
            runOnUiThread { 
                result.error(PolarErrorCode.INVALID_ARGUMENT, e.message, null)
            }
        }
    }

    private fun getDiskSpace(call: MethodCall, result: Result) {
        val identifier = call.arguments as String

        wrapper.api
            .getDiskSpace(identifier)
            .subscribe({
                val (availableSpace, freeSpace) = it
                runOnUiThread {
                    result.success(listOf(availableSpace, freeSpace))
                }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun getLocalTime(call: MethodCall, result: Result) {
        val identifier = call.arguments as? String ?: run {
            result.error("ERROR_INVALID_ARGUMENT", "Expected a single String argument", null)
            return
        }

        wrapper.api
            .getLocalTime(identifier)
            .subscribe({ deviceTime ->
                try {
                    // Format the device time using SimpleDateFormat
                    val dateFormat = java.text.SimpleDateFormat(
                        "yyyy-MM-dd'T'HH:mm:ssXXX",
                        java.util.Locale.getDefault()
                    )
                    dateFormat.timeZone = deviceTime.timeZone
                    val timeString = dateFormat.format(deviceTime.time)

                    // Return the formatted date as a string
                    runOnUiThread {
                        result.success(timeString)
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        result.error("ERROR_FORMATTING_TIME", e.message, null)
                    }
                }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun setLocalTime(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val timestamp = arguments[1] as Double

        // Convert the timestamp to a Date object
        val date =
            java.util.Date((timestamp * 1000).toLong()) // Multiply by 1000 to convert seconds to milliseconds

        // Convert Date to Calendar
        val calendar = java.util.Calendar.getInstance()
        calendar.time = date

        // Now, call the API with Calendar
        wrapper.api
            .setLocalTime(identifier, calendar)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun doFirstTimeUse(call: MethodCall, result: Result) {
        val arguments = call.arguments as Map<*, *>
        val identifier = arguments["identifier"] as? String
        val configMap = arguments["config"] as? Map<*, *>

        if (identifier == null || configMap == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "Expected identifier and config map",
                null
            )
            return
        }
        // Extract configuration values
        val gender = configMap["gender"] as? String
        val birthDateString = configMap["birthDate"] as? String
        val height = (configMap["height"] as? Int)?.toFloat()
        val weight = (configMap["weight"] as? Int)?.toFloat()
        val maxHeartRate = configMap["maxHeartRate"] as? Int
        val vo2Max = configMap["vo2Max"] as? Int
        val restingHeartRate = configMap["restingHeartRate"] as? Int
        val trainingBackground = configMap["trainingBackground"] as? Int
        val deviceTime = configMap["deviceTime"] as? String
        val typicalDay = configMap["typicalDay"] as? Int
        val sleepGoalMinutes = configMap["sleepGoalMinutes"] as? Int

        // Validate required parameters
        if (gender == null || birthDateString == null || height == null || weight == null ||
            maxHeartRate == null || vo2Max == null || restingHeartRate == null ||
            trainingBackground == null || deviceTime == null || typicalDay == null ||
            sleepGoalMinutes == null
        ) {
            result.error(
                "INVALID_CONFIG",
                "Invalid configuration parameters",
                null
            )
            return
        }

        // Parse birth date
        val birthDate = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).parse(birthDateString)

        // Map gender string to PolarFirstTimeUseConfig.Gender enum
        val genderEnum = when (gender) {
            "Male" -> PolarFirstTimeUseConfig.Gender.MALE
            "Female" -> PolarFirstTimeUseConfig.Gender.FEMALE
            else -> throw IllegalArgumentException("Invalid gender value")
        }

        // Map typicalDay to PolarFirstTimeUseConfig.TypicalDay enum
        val typicalDayEnum = when (typicalDay) {
            1 -> PolarFirstTimeUseConfig.TypicalDay.MOSTLY_MOVING
            2 -> PolarFirstTimeUseConfig.TypicalDay.MOSTLY_SITTING
            3 -> PolarFirstTimeUseConfig.TypicalDay.MOSTLY_STANDING
            else -> PolarFirstTimeUseConfig.TypicalDay.MOSTLY_SITTING // Default
        }

        // Create PolarFirstTimeUseConfig instance
        val ftuConfig = PolarFirstTimeUseConfig(
            genderEnum,
            birthDate,
            height,
            weight,
            maxHeartRate,
            vo2Max,
            restingHeartRate,
            trainingBackground,
            deviceTime,
            typicalDayEnum,
            sleepGoalMinutes
        )

        // Call the Polar API
        wrapper.api
            .doFirstTimeUse(identifier, ftuConfig)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, {
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun stopSleepRecording(
        call: MethodCall,
        result: Result,
    ) {
        val identifier = call.arguments as String

        wrapper.api
            .stopSleepRecording(identifier)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, { error ->
                runOnUiThread {
                    val errorCode = when {
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }

    private fun isFtuDone(call: MethodCall, result: Result) {
        val identifier = call.arguments as? String ?: run {
            result.error("ERROR_INVALID_ARGUMENT", "Expected a single String argument", null)
            return
        }

        println("[PolarPlugin] isFtuDone called for device $identifier")

        wrapper.api
            .isFtuDone(identifier)
            .doOnError { error -> 
                println("[PolarPlugin] Error in isFtuDone: ${error.message}")
                System.err.println("The error message is: " + error.message) 
            }
            .subscribe({ isFtuDone ->
                println("[PolarPlugin] isFtuDone result: $isFtuDone")
                runOnUiThread { result.success(isFtuDone) }
            }, { error ->
                println("[PolarPlugin] Error getting FTU status: ${error.message}")
                runOnUiThread {
                    val errorCode = when {
                        error.message?.contains("PftpOperationTimeout") == true -> PolarErrorCode.TIMEOUT
                        error.message?.contains("Air packet was not received") == true -> PolarErrorCode.TIMEOUT
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }

    private fun getSleep(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val fromDate = LocalDate.parse(arguments[1] as String)
        val toDate = LocalDate.parse(arguments[2] as String)

        // Create formatters for different date types
        val dateTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS")
        val dateFormatter = DateTimeFormatter.ISO_LOCAL_DATE
        
        // For debugging timezone issues
        println("[PolarPlugin] getSleep called with fromDate=$fromDate, toDate=$toDate")
        
        wrapper.api
            .getSleep(identifier, fromDate, toDate)
            .doOnError { error -> System.err.println("The error message is: " + error.message) }
            .subscribe({ sleepDataList ->
                println("[PolarPlugin] getSleep received ${sleepDataList.size} sleep records")
                
                // Debug the data we're getting back to help identify timezone issues
                sleepDataList.forEach { sleepData ->
                    println("[PolarPlugin] Sleep data date: ${sleepData.date}, result date: ${sleepData.result?.sleepResultDate}")
                }
                
                runOnUiThread {
                    val jsonArray = sleepDataList.map { sleepData ->
                        mapOf(
                            "date" to (sleepData.date?.format(dateFormatter)), // LocalDate
                            "result" to mapOf(
                                "batteryRanOut" to sleepData.result?.batteryRanOut,
                                "deviceId" to sleepData.result?.deviceId,
                                "lastModified" to (sleepData.result?.lastModified?.format(dateTimeFormatter)), // LocalDateTime
                                "sleepCycles" to sleepData.result?.sleepCycles?.map { cycle ->
                                    mapOf(
                                        "secondsFromSleepStart" to cycle.secondsFromSleepStart,
                                        "sleepDepthStart" to cycle.sleepDepthStart
                                    )
                                },
                                "sleepEndOffsetSeconds" to sleepData.result?.sleepEndOffsetSeconds,
                                "sleepEndTime" to (sleepData.result?.sleepEndTime?.format(dateTimeFormatter)), // LocalDateTime
                                "sleepGoalMinutes" to sleepData.result?.sleepGoalMinutes,
                                "sleepResultDate" to (sleepData.result?.sleepResultDate?.format(dateFormatter)), // LocalDate
                                "sleepStartOffsetSeconds" to sleepData.result?.sleepStartOffsetSeconds,
                                "sleepStartTime" to (sleepData.result?.sleepStartTime?.format(dateTimeFormatter)), // LocalDateTime
                                "sleepWakePhases" to sleepData.result?.sleepWakePhases?.map { phase ->
                                    mapOf(
                                        "secondsFromSleepStart" to phase.secondsFromSleepStart,
                                        "state" to phase.state.name
                                    )
                                }
                            )
                        )
                    }
                    result.success(gson.toJson(jsonArray))
                }
            }, {
                println("[PolarPlugin] getSleep error: ${it.message}")
                runOnUiThread {
                    result.error(it.toString(), it.message, null)
                }
            })
            .discard()
    }

    private fun getSleepRecordingState(call: MethodCall, result: Result) {
        val identifier = call.arguments as String
        println("[PolarPlugin] getSleepRecordingState called for device $identifier")
        
        wrapper.api
            .getSleepRecordingState(identifier)
            .subscribe({ isRecording ->
                println("[PolarPlugin] getSleepRecordingState SUCCESS: $isRecording")
                runOnUiThread { 
                    result.success(isRecording)
                }
            }, { error ->
                println("[PolarPlugin] getSleepRecordingState ERROR: ${error.message}")
                
                runOnUiThread {
                    val errorCode = when {
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, "getSleepRecordingState failed: ${error.message}", 
                        mapOf("deviceId" to identifier))
                }
            })
            .discard()
    }


    
    private fun setupSleepStateObservation(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val eventChannelName = arguments[0] as String
        val identifier = arguments[1] as String
        
        println("[PolarPlugin] Setting up sleep state observation for $identifier on channel $eventChannelName")
        
        // Create an event channel for this observation
        val eventChannel = EventChannel(messenger, eventChannelName)
        
        // Set up the handler for the event channel
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            private var stateSubscription: Disposable? = null
            
            override fun onListen(arguments: Any?, events: EventSink?) {
                if (events == null) {
                    println("[PolarPlugin] Events sink is null for sleep state observation")
                    return
                }
                
                println("[PolarPlugin] Starting sleep state observation for $identifier")
                
                stateSubscription = wrapper.api
                    .observeSleepRecordingState(identifier)
                    .subscribe({ state ->
                        println("[PolarPlugin] Sleep state changed: $state")
                        runOnUiThread { events.success(state[0]) } // First element is the sleep state
                    }, { error ->
                        println("[PolarPlugin] Error in sleep state observation: ${error.message}")
                        runOnUiThread {
                            val errorCode = when {
                                error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                                error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                                else -> PolarErrorCode.BLUETOOTH_ERROR
                            }
                            events.error(errorCode, error.message, null)
                        }
                    }, {
                        println("[PolarPlugin] Sleep state observation completed")
                        runOnUiThread { events.endOfStream() }
                    })
            }
            
            override fun onCancel(arguments: Any?) {
                println("[PolarPlugin] Cancelling sleep state observation for $identifier")
                stateSubscription?.dispose()
                stateSubscription = null
            }
        })
        
        // Indicate successful setup
        result.success(null)
    }

    private fun get247PPiSamples(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
        calendar.timeInMillis = arguments[1] as Long
        val fromDate = calendar.time

        calendar.timeInMillis = arguments[2] as Long
        val toDate = calendar.time
        
        // Format dates in UTC for logging
        val utcFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss 'UTC'", Locale.US)
        utcFormat.timeZone = TimeZone.getTimeZone("UTC")
        
        println("[PolarPlugin] get247PPiSamples called with fromDate=${utcFormat.format(fromDate)}, toDate=${utcFormat.format(toDate)}")
        
        wrapper.api
            .get247PPiSamples(identifier, fromDate, toDate)
            .subscribe({ ppiSamplesList ->
                println("[PolarPlugin] get247PPiSamples received ${ppiSamplesList.size} samples")
                
                // Debug the data we're getting back
                ppiSamplesList.forEach { ppiSample ->
                    println("[PolarPlugin] PPi sample date: ${ppiSample.date}")
                }
                
                runOnUiThread {
                    val jsonArray = ppiSamplesList.map { ppiSample ->
                        mapOf(
                            "date" to ppiSample.date.time,
                            "samples" to mapOf(
                                "startTime" to ppiSample.samples.startTime.toString(),
                                "triggerType" to ppiSample.samples.triggerType.name,
                                "ppiValueList" to ppiSample.samples.ppiValueList,
                                "ppiErrorEstimateList" to ppiSample.samples.ppiErrorEstimateList,
                                "statusList" to ppiSample.samples.statusList.map { status ->
                                    mapOf(
                                        "skinContact" to status.skinContact.name,
                                        "movement" to status.movement.name,
                                        "intervalStatus" to status.intervalStatus.name
                                    )
                                }
                            )
                        )
                    }
                    result.success(gson.toJson(jsonArray))
                }
            }, {
                println("[PolarPlugin] get247PPiSamples error: ${it.message}")
                runOnUiThread {
                    val errorCode = when {
                        it is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        it is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        it.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, it.message, null)
                }
            })
            .discard()
    }

    private fun deleteDeviceDateFolders(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val fromDate = LocalDate.parse(arguments[1] as String)
        val toDate = LocalDate.parse(arguments[2] as String)

        println("[PolarPlugin] deleteDeviceDateFolders called with identifier=$identifier, fromDate=$fromDate, toDate=$toDate")

        wrapper.api
            .deleteDeviceDateFolders(identifier, fromDate, toDate)
            .doOnSubscribe { 
                println("[PolarPlugin] Starting deleteDeviceDateFolders operation")
            }
            .doOnComplete {
                println("[PolarPlugin] deleteDeviceDateFolders operation completed - folders between $fromDate and $toDate processed")
            }
            .subscribe({
                println("[PolarPlugin] deleteDeviceDateFolders completed successfully")
                runOnUiThread { result.success(null) }
            }, { error ->
                println("[PolarPlugin] deleteDeviceDateFolders error: ${error.message}")
                runOnUiThread {
                    val errorCode = when {
                        error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }

    private fun deleteStoredDeviceData(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val dataTypeStr = arguments[1] as String
        val untilDateStr = arguments[2] as String

        println("[PolarPlugin] deleteStoredDeviceData called with identifier=$identifier, dataType=$dataTypeStr, until=$untilDateStr")

        // Parse the date string (YYYY-MM-DD format)
        val untilDate = LocalDate.parse(untilDateStr)
        
        // Convert string to PolarStoredDataType
        val dataType = when (dataTypeStr) {
            "ACTIVITY" -> PolarBleApi.PolarStoredDataType.ACTIVITY
            "AUTO_SAMPLE" -> PolarBleApi.PolarStoredDataType.AUTO_SAMPLE
            "DAILY_SUMMARY" -> PolarBleApi.PolarStoredDataType.DAILY_SUMMARY
            "NIGHTLY_RECOVERY" -> PolarBleApi.PolarStoredDataType.NIGHTLY_RECOVERY
            "SDLOGS" -> PolarBleApi.PolarStoredDataType.SDLOGS
            "SLEEP" -> PolarBleApi.PolarStoredDataType.SLEEP
            "SLEEP_SCORE" -> PolarBleApi.PolarStoredDataType.SLEEP_SCORE
            "SKIN_CONTACT_CHANGES" -> PolarBleApi.PolarStoredDataType.SKIN_CONTACT_CHANGES
            "SKIN_TEMP" -> PolarBleApi.PolarStoredDataType.SKIN_TEMP
            else -> {
                runOnUiThread {
                    result.error(PolarErrorCode.INVALID_ARGUMENT, "Unknown data type: $dataTypeStr", null)
                }
                return
            }
        }

        wrapper.api
            .deleteStoredDeviceData(identifier, dataType, untilDate)
            .doOnSubscribe { 
                println("[PolarPlugin] Starting deleteStoredDeviceData operation for $dataTypeStr until $untilDate")
            }
            .doOnComplete {
                println("[PolarPlugin] deleteStoredDeviceData operation completed for $dataTypeStr")
            }
            .subscribe({
                println("[PolarPlugin] deleteStoredDeviceData completed successfully for $dataTypeStr")
                runOnUiThread { result.success(null) }
            }, { error ->
                println("[PolarPlugin] deleteStoredDeviceData error for $dataTypeStr: ${error.message}")
                runOnUiThread {
                    val errorCode = when {
                        error.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> "NO_SUCH_FILE_OR_DIRECTORY"
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }

    private fun setOfflineRecordingTrigger(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val triggerJson = arguments[1] as String

        try {
            val triggerData = gson.fromJson(triggerJson, Map::class.java) as Map<String, Any>
            val triggerModeString = triggerData["triggerMode"] as String
            val triggerFeaturesMap = triggerData["triggerFeatures"] as Map<String, Any?>

            // Convert trigger mode from Dart camelCase to official SDK enum constants
            val triggerMode = when (triggerModeString) {
                "triggerDisabled" -> PolarOfflineRecordingTriggerMode.TRIGGER_DISABLED
                "triggerSystemStart" -> PolarOfflineRecordingTriggerMode.TRIGGER_SYSTEM_START
                "triggerExerciseStart" -> PolarOfflineRecordingTriggerMode.TRIGGER_EXERCISE_START
                else -> throw IllegalArgumentException("Unknown trigger mode: $triggerModeString")
            }

            // Convert trigger features map
            val triggerFeatures = mutableMapOf<PolarDeviceDataType, PolarSensorSetting?>()
            triggerFeaturesMap.forEach { (dataTypeString, settingsValue) ->
                val dataType = when (dataTypeString) {
                    "ppi" -> PolarDeviceDataType.PPI
                    "hr" -> PolarDeviceDataType.HR
                    "ecg" -> PolarDeviceDataType.ECG
                    "acc" -> PolarDeviceDataType.ACC
                    "ppg" -> PolarDeviceDataType.PPG
                    "gyro" -> PolarDeviceDataType.GYRO
                    "magnetometer" -> PolarDeviceDataType.MAGNETOMETER
                    "temperature" -> PolarDeviceDataType.TEMPERATURE
                    "pressure" -> PolarDeviceDataType.PRESSURE
                    else -> throw IllegalArgumentException("Unknown data type: $dataTypeString")
                }
                
                // For PPI and HR, settings should be null
                val settings = if (settingsValue != null && dataType != PolarDeviceDataType.PPI && dataType != PolarDeviceDataType.HR) {
                    gson.fromJson(gson.toJson(settingsValue), PolarSensorSetting::class.java)
                } else {
                    null
                }
                
                triggerFeatures[dataType] = settings
            }

            val trigger = PolarOfflineRecordingTrigger(triggerMode, triggerFeatures)

            wrapper.api
                .setOfflineRecordingTrigger(identifier, trigger, null)
                .subscribe({
                    runOnUiThread { result.success(null) }
                }, { error ->
                    runOnUiThread {
                        val errorCode = when {
                            error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                            error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                            error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                            else -> PolarErrorCode.BLUETOOTH_ERROR
                        }
                        result.error(errorCode, error.message, null)
                    }
                })
                .discard()
        } catch (e: Exception) {
            result.error(PolarErrorCode.INVALID_ARGUMENT, "Failed to parse trigger: ${e.message}", null)
        }
    }

    private fun doRestart(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        // Note: preservePairingInformation is ignored on Android as the API only takes identifier

        wrapper.api
            .doRestart(identifier)
            .subscribe({
                runOnUiThread { result.success(null) }
            }, { error ->
                runOnUiThread {
                    val errorCode = when {
                        error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                        error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                        error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                        else -> PolarErrorCode.BLUETOOTH_ERROR
                    }
                    result.error(errorCode, error.message, null)
                }
            })
            .discard()
    }


    private fun updateFirmware(call: MethodCall, result: Result) {
        val arguments = call.arguments as List<*>
        val identifier = arguments[0] as String
        val firmwareUrl = arguments[1] as String

        try {
            initApi()
            
            firmwareUpdateSubscription = wrapper.api.updateFirmware(identifier, firmwareUrl)
                .subscribe(
                    { status ->
                        runOnUiThread {
                            val statusMap = mapOf(
                                "status" to status.javaClass.simpleName,
                                "details" to when (status) {
                                    is FirmwareUpdateStatus.FetchingFwUpdatePackage -> status.details
                                    is FirmwareUpdateStatus.PreparingDeviceForFwUpdate -> status.details
                                    is FirmwareUpdateStatus.WritingFwUpdatePackage -> status.details
                                    is FirmwareUpdateStatus.FinalizingFwUpdate -> status.details
                                    is FirmwareUpdateStatus.FwUpdateCompletedSuccessfully -> status.details
                                    is FirmwareUpdateStatus.FwUpdateNotAvailable -> status.details
                                    is FirmwareUpdateStatus.FwUpdateFailed -> status.details
                                    else -> "Unknown status"
                                }
                            )
                            firmwareUpdateEvents?.success(statusMap)
                        }
                    },
                    { error ->
                        runOnUiThread {
                            val errorCode = when {
                                error is PolarDeviceDisconnected -> PolarErrorCode.DEVICE_DISCONNECTED
                                error is PolarOperationNotSupported -> PolarErrorCode.NOT_SUPPORTED
                                error.message?.contains("timeout", ignoreCase = true) == true -> PolarErrorCode.TIMEOUT
                                else -> PolarErrorCode.BLUETOOTH_ERROR
                            }
                            firmwareUpdateEvents?.error(errorCode, error.message, null)
                        }
                    },
                    {
                        runOnUiThread { 
                            firmwareUpdateEvents?.endOfStream()
                        }
                    }
                )
            
            // Return success immediately to indicate the update process has started
            result.success(null)
        } catch (e: Exception) {
            result.error(PolarErrorCode.BLUETOOTH_ERROR, "Failed to start firmware update: ${e.message}", null)
        }
    }
}

class PolarWrapper @OptIn(ExperimentalStdlibApi::class) constructor(
    context: Context,
    val api: PolarBleApi =
        PolarBleApiDefaultImpl.defaultImplementation(
            context,
            PolarBleSdkFeature.values().toSet(),
        ),
    private val callbacks: MutableSet<(String, Any?) -> Unit> = mutableSetOf(),
) : PolarBleApiCallbackProvider {
    
    companion object {
        private const val TAG = "PolarWrapper"
    }
    
    init {
        // Setup global RxJava error handler to prevent unhandled exceptions
        RxJavaPlugins.setErrorHandler { e: Throwable ->
            when {
                e is OnErrorNotImplementedException && e.cause?.message?.contains("NO_SUCH_FILE_OR_DIRECTORY") == true -> {
                    println("[$TAG] Safely caught NO_SUCH_FILE_OR_DIRECTORY exception from SDK: ${e.cause?.message}")
                }
                e is OnErrorNotImplementedException -> {
                    println("[$TAG] Caught undeliverable RxJava exception from SDK: ${e.cause?.message ?: e.message}")
                }
                else -> {
                    println("[$TAG] Caught RxJava error from SDK: ${e.message}")
                }
            }
            // Don't rethrow - prevent crashes
        }
        
        api.setApiCallback(this)
    }

    fun addCallback(callback: (String, Any?) -> Unit) {
        if (callbacks.contains(callback)) return
        callbacks.add(callback)
    }

    fun removeCallback(callback: (String, Any?) -> Unit) {
        callbacks.remove(callback)
    }

    private fun invoke(
        method: String,
        arguments: Any?,
    ) {
        callbacks.forEach { it(method, arguments) }
    }

    fun shutDown() {
        // Do not shutdown the api if other engines are still using it
        if (callbacks.isNotEmpty()) return
        try {
            api.shutDown()
        } catch (e: Exception) {
            // This will throw if the API is already shut down
        }
    }

    override fun blePowerStateChanged(powered: Boolean) {
        invoke("blePowerStateChanged", powered)
    }

    override fun bleSdkFeatureReady(
        identifier: String,
        feature: PolarBleSdkFeature,
    ) {
        invoke("sdkFeatureReady", listOf(identifier, feature.name))
    }

    override fun deviceConnected(polarDeviceInfo: PolarDeviceInfo) {
        invoke("deviceConnected", gson.toJson(polarDeviceInfo))
    }

    override fun deviceConnecting(polarDeviceInfo: PolarDeviceInfo) {
        invoke("deviceConnecting", gson.toJson(polarDeviceInfo))
    }

    override fun deviceDisconnected(polarDeviceInfo: PolarDeviceInfo) {
        invoke(
            "deviceDisconnected",
            // The second argument is the `pairingError` field on iOS
            // Since Android doesn't implement that, always send false
            listOf(gson.toJson(polarDeviceInfo), false),
        )
    }

    override fun disInformationReceived(
        identifier: String,
        uuid: UUID,
        value: String,
    ) {
        invoke("disInformationReceived", listOf(identifier, uuid.toString(), value))
    }

    override fun disInformationReceived(
        identifier: String,
        disInfo: DisInfo,
    ) {
        invoke("disInformationReceived", listOf(identifier, disInfo.key, disInfo.value))
    }

    override fun batteryLevelReceived(
        identifier: String,
        level: Int,
    ) {
        invoke("batteryLevelReceived", listOf(identifier, level))
    }

    override fun batteryChargingStatusReceived(
        identifier: String, 
        chargingStatus: ChargeState
    ) {
        // TODO: Implement this if needed
        // For now, we're just providing a stub implementation
    }

    @Deprecated("", replaceWith = ReplaceWith(""))
    fun hrFeatureReady(identifier: String) {
        // Do nothing
    }

    @Deprecated("", replaceWith = ReplaceWith(""))
    override fun hrNotificationReceived(
        identifier: String,
        data: PolarHrData.PolarHrSample,
    ) {
        // Do nothing
    }

    override fun htsNotificationReceived(identifier: String, data: PolarHealthThermometerData) {
        TODO("Not yet implemented")
    }

    @Deprecated("", replaceWith = ReplaceWith(""))
    fun polarFtpFeatureReady(identifier: String) {
        // Do nothing
    }

    @Deprecated("", replaceWith = ReplaceWith(""))
    fun sdkModeFeatureAvailable(identifier: String) {
        // Do nothing
    }

    @Deprecated("", replaceWith = ReplaceWith(""))
    fun streamingFeaturesReady(
        identifier: String,
        features: Set<PolarDeviceDataType>,
    ) {
        // Do nothing
    }
}

class StreamingChannel(
    messenger: BinaryMessenger,
    name: String,
    private val api: PolarBleApi,
    private val identifier: String,
    private val feature: PolarDeviceDataType,
    private val channel: EventChannel = EventChannel(messenger, name),
) : EventChannel.StreamHandler {
    private var subscription: Disposable? = null

    init {
        channel.setStreamHandler(this)
    }

    override fun onListen(
        arguments: Any?,
        events: EventSink,
    ) {
        // Will be null for some features
        val settings = gson.fromJson(arguments as String, PolarSensorSetting::class.java)

        val stream =
            when (feature) {
                PolarDeviceDataType.HR -> api.startHrStreaming(identifier)
                PolarDeviceDataType.ECG -> api.startEcgStreaming(identifier, settings)
                PolarDeviceDataType.ACC -> api.startAccStreaming(identifier, settings)
                PolarDeviceDataType.PPG -> api.startPpgStreaming(identifier, settings)
                PolarDeviceDataType.PPI -> api.startPpiStreaming(identifier)
                PolarDeviceDataType.GYRO -> api.startGyroStreaming(identifier, settings)
                PolarDeviceDataType.MAGNETOMETER ->
                    api.startMagnetometerStreaming(
                        identifier,
                        settings,
                    )

                PolarDeviceDataType.TEMPERATURE ->
                    api.startTemperatureStreaming(
                        identifier,
                        settings,
                    )

                PolarDeviceDataType.PRESSURE -> TODO()
                PolarDeviceDataType.LOCATION -> TODO()
                PolarDeviceDataType.SKIN_TEMPERATURE -> TODO()
            }

        subscription =
            stream.subscribe({
                runOnUiThread { events.success(gson.toJson(it)) }
            }, {
                runOnUiThread {
                    events.error(it.toString(), it.message, null)
                }
            }, {
                runOnUiThread { events.endOfStream() }
            })
    }

    override fun onCancel(arguments: Any?) {
        subscription?.dispose()
    }

    fun dispose() {
        subscription?.dispose()
        channel.setStreamHandler(null)
    }
}
