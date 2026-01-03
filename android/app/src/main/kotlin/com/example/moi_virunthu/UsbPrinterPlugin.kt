package com.example.moi_virunthu

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.hardware.usb.UsbEndpoint
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class UsbPrinterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var usbManager: UsbManager? = null
    private var currentConnection: UsbDeviceConnection? = null
    private var currentEndpoint: UsbEndpoint? = null
    private var currentInterface: UsbInterface? = null

    companion object {
        private const val TAG = "UsbPrinterPlugin"
        private const val ACTION_USB_PERMISSION = "com.example.moi_virunthu.USB_PERMISSION"
        private const val USB_CLASS_PRINTER = 7
        private const val TIMEOUT_MS = 5000
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "usb_printer_native")
        channel.setMethodCallHandler(this)
        usbManager = context.getSystemService(Context.USB_SERVICE) as UsbManager
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        disconnect()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getUsbDevices" -> getUsbDevices(result)
            "connectUsb" -> {
                val vid = call.argument<Int>("vid")
                val pid = call.argument<Int>("pid")
                if (vid != null && pid != null) {
                    connectUsb(vid, pid, result)
                } else {
                    result.error("INVALID_ARGS", "VID and PID required", null)
                }
            }
            "disconnect" -> {
                disconnect()
                result.success(true)
            }
            "printRawBytes" -> {
                val bytes = call.argument<ByteArray>("data")
                if (bytes != null) {
                    printRawBytes(bytes, result)
                } else {
                    result.error("INVALID_ARGS", "Data required", null)
                }
            }
            "isConnected" -> result.success(currentConnection != null)
            else -> result.notImplemented()
        }
    }

    private fun getUsbDevices(result: MethodChannel.Result) {
        try {
            val deviceList = usbManager?.deviceList ?: emptyMap()
            val devices = deviceList.values.map { device ->
                mapOf(
                    "vid" to device.vendorId,
                    "pid" to device.productId,
                    "deviceName" to device.deviceName,
                    "productName" to (device.productName ?: "USB Printer"),
                    "manufacturerName" to (device.manufacturerName ?: "Unknown"),
                    "serialNumber" to (device.serialNumber ?: "")
                )
            }
            Log.d(TAG, "Found ${devices.size} USB devices")
            result.success(devices)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting USB devices", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun connectUsb(vid: Int, pid: Int, result: MethodChannel.Result) {
        try {
            Log.d(TAG, "Connecting to USB device - VID: $vid, PID: $pid")

            val device = findDevice(vid, pid)
            if (device == null) {
                Log.e(TAG, "Device not found")
                result.error("NOT_FOUND", "USB device not found", null)
                return
            }

            if (!usbManager!!.hasPermission(device)) {
                Log.d(TAG, "Requesting USB permission")
                requestPermission(device) { granted ->
                    if (granted) {
                        performConnection(device, result)
                    } else {
                        result.error("PERMISSION_DENIED", "USB permission denied", null)
                    }
                }
            } else {
                performConnection(device, result)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Connection error", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun performConnection(device: UsbDevice, result: MethodChannel.Result) {
        try {
            disconnect()

            val printerInterface = findPrinterInterface(device)
            if (printerInterface == null) {
                Log.e(TAG, "No printer interface found")
                result.error("NO_INTERFACE", "No printer interface found", null)
                return
            }

            val endpoint = findBulkOutEndpoint(printerInterface)
            if (endpoint == null) {
                Log.e(TAG, "No BULK OUT endpoint found")
                result.error("NO_ENDPOINT", "No BULK OUT endpoint found", null)
                return
            }

            val connection = usbManager!!.openDevice(device)
            if (connection == null) {
                Log.e(TAG, "Failed to open device")
                result.error("OPEN_FAILED", "Failed to open USB device", null)
                return
            }

            if (!connection.claimInterface(printerInterface, true)) {
                connection.close()
                Log.e(TAG, "Failed to claim interface")
                result.error("CLAIM_FAILED", "Failed to claim USB interface", null)
                return
            }

            currentConnection = connection
            currentEndpoint = endpoint
            currentInterface = printerInterface

            Log.d(TAG, "USB connected successfully")
            Log.d(TAG, "Interface: ${printerInterface.interfaceClass}")
            Log.d(TAG, "Endpoint: ${endpoint.address}, MaxPacket: ${endpoint.maxPacketSize}")

            val initCmd = byteArrayOf(0x1B, 0x40)
            connection.bulkTransfer(endpoint, initCmd, initCmd.size, TIMEOUT_MS)

            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Connection error", e)
            disconnect()
            result.error("ERROR", e.message, null)
        }
    }

    private fun findDevice(vid: Int, pid: Int): UsbDevice? {
        val deviceList = usbManager?.deviceList ?: return null
        return deviceList.values.find { it.vendorId == vid && it.productId == pid }
    }

    private fun findPrinterInterface(device: UsbDevice): UsbInterface? {
        for (i in 0 until device.interfaceCount) {
            val intf = device.getInterface(i)
            if (intf.interfaceClass == USB_CLASS_PRINTER) {
                Log.d(TAG, "Found printer interface: $i")
                return intf
            }
        }
        return if (device.interfaceCount > 0) device.getInterface(0) else null
    }

    private fun findBulkOutEndpoint(intf: UsbInterface): UsbEndpoint? {
        for (i in 0 until intf.endpointCount) {
            val endpoint = intf.getEndpoint(i)
            if (endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                endpoint.direction == UsbConstants.USB_DIR_OUT) {
                Log.d(TAG, "Found BULK OUT endpoint: ${endpoint.address}")
                return endpoint
            }
        }
        return null
    }

    private fun requestPermission(device: UsbDevice, callback: (Boolean) -> Unit) {
        val permissionIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(ACTION_USB_PERMISSION),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
        )

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (ACTION_USB_PERMISSION == intent.action) {
                    context.unregisterReceiver(this)
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    callback(granted)
                }
            }
        }

        context.registerReceiver(receiver, IntentFilter(ACTION_USB_PERMISSION))
        usbManager?.requestPermission(device, permissionIntent)
    }

    private fun printRawBytes(data: ByteArray, result: MethodChannel.Result) {
        try {
            if (currentConnection == null || currentEndpoint == null) {
                result.error("NOT_CONNECTED", "USB printer not connected", null)
                return
            }

            Log.d(TAG, "Printing ${data.size} bytes")

            val chunkSize = currentEndpoint!!.maxPacketSize
            var offset = 0

            while (offset < data.size) {
                val length = minOf(chunkSize, data.size - offset)
                val chunk = data.copyOfRange(offset, offset + length)

                val transferred = currentConnection!!.bulkTransfer(
                    currentEndpoint!!,
                    chunk,
                    length,
                    TIMEOUT_MS
                )

                if (transferred < 0) {
                    Log.e(TAG, "Transfer failed at offset $offset")
                    result.error("TRANSFER_FAILED", "USB transfer failed", null)
                    return
                }

                offset += transferred
            }

            Log.d(TAG, "Print successful")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Print error", e)
            result.error("ERROR", e.message, null)
        }
    }

    private fun disconnect() {
        try {
            currentInterface?.let { currentConnection?.releaseInterface(it) }
            currentConnection?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Disconnect error", e)
        } finally {
            currentConnection = null
            currentEndpoint = null
            currentInterface = null
        }
    }
}