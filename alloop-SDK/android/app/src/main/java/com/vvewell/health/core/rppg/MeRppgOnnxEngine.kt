package com.vvewell.health.core.rppg

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OnnxJavaType
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import java.nio.FloatBuffer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.float
import kotlinx.serialization.json.jsonPrimitive

/**
 * ONNX Runtime port of knowell/me_processor.py's recurrent inference loop.
 *
 * Model and state are loaded from app assets. No frame or signal leaves the device.
 */
class MeRppgOnnxEngine(
    context: Context,
    private val json: Json = Json,
) : RppgInferenceEngine {
    private val environment = OrtEnvironment.getEnvironment()
    private val session: OrtSession = context.assets.open(MODEL_ASSET).use {
        environment.createSession(it.readBytes())
    }
    private val initialState = context.assets.open(STATE_ASSET).bufferedReader().use { reader ->
        parseState(json.parseToJsonElement(reader.readText()) as JsonObject)
    }
    private val recurrentState = RppgRecurrentState(initialState)

    init {
        validateSessionContract()
    }

    override fun processFrame(rgb: FloatArray, frameDeltaSeconds: Float): Float {
        require(rgb.size == RppgImagePreprocessor.MODEL_SIZE * RppgImagePreprocessor.MODEL_SIZE * 3) {
            "rPPG 输入必须是 36×36 RGB FloatArray"
        }
        val tensors = linkedMapOf<String, OnnxTensor>()
        try {
            tensors[RppgModelContract.IMAGE_INPUT_NAME] = tensor(rgb, RppgImagePreprocessor.MODEL_INPUT_SHAPE)
            tensors[RppgModelContract.DELTA_INPUT_NAME] = scalarTensor(frameDeltaSeconds)
            recurrentState.current.forEach { (name, value) ->
                tensors[name] = tensor(value.data, value.shape)
            }

            session.run(tensors).use { result ->
                val bvpTensor = result[0] as OnnxTensor
                val bvp = bvpTensor.floatBuffer.get(0)
                val nextState = linkedMapOf<String, RppgTensorState>()
                recurrentState.current.keys.forEachIndexed { index, name ->
                    val output = result[index + 1] as OnnxTensor
                    val buffer = output.floatBuffer
                    val data = FloatArray(buffer.remaining())
                    buffer.get(data)
                    nextState[name] = RppgTensorState(
                        data = data,
                        shape = output.info.shape,
                    )
                }
                recurrentState.replace(nextState)
                return bvp
            }
        } finally {
            tensors.values.forEach(OnnxTensor::close)
        }
    }

    override fun reset() {
        recurrentState.reset()
    }

    override fun close() {
        session.close()
    }

    private fun tensor(values: FloatArray, shape: LongArray): OnnxTensor =
        OnnxTensor.createTensor(environment, FloatBuffer.wrap(values), shape)

    private fun scalarTensor(value: Float): OnnxTensor =
        OnnxTensor.createTensor(environment, FloatBuffer.wrap(floatArrayOf(value)), longArrayOf())

    private fun parseState(root: JsonObject): LinkedHashMap<String, RppgTensorState> =
        linkedMapOf<String, RppgTensorState>().apply {
            root.forEach { (name, element) ->
                val dimensions = mutableListOf<Long>()
                findShape(element, dimensions)
                val flattened = mutableListOf<Float>()
                flatten(element, flattened)
                put(name, RppgTensorState(flattened.toFloatArray(), dimensions.toLongArray()))
            }
        }

    private fun findShape(element: JsonElement, dimensions: MutableList<Long>) {
        if (element is JsonArray) {
            dimensions += element.size.toLong()
            element.firstOrNull()?.let { findShape(it, dimensions) }
        }
    }

    private fun flatten(element: JsonElement, destination: MutableList<Float>) {
        when (element) {
            is JsonArray -> element.forEach { flatten(it, destination) }
            else -> destination += element.jsonPrimitive.float
        }
    }

    private fun validateSessionContract() {
        val inputs = session.inputInfo.mapValues { (_, node) -> node.toSchema() }
        val outputs = session.outputInfo.values.map { it.toSchema() }
        RppgModelContract.validate(inputs, outputs, initialState)
    }

    private fun ai.onnxruntime.NodeInfo.toSchema(): RppgTensorSchema {
        val tensorInfo = getInfo() as? TensorInfo ?: error("rPPG model value ${getName()} is not a tensor")
        return RppgTensorSchema(
            name = getName(),
            type = if (tensorInfo.type == OnnxJavaType.FLOAT) RppgTensorType.Float32 else RppgTensorType.Other,
            shape = tensorInfo.shape,
        )
    }

    private companion object {
        const val MODEL_ASSET = "rppg/model.onnx"
        const val STATE_ASSET = "rppg/state.json"
    }
}
