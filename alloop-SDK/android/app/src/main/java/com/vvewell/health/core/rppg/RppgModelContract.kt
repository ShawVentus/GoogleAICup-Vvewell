package com.vvewell.health.core.rppg

internal enum class RppgTensorType {
    Float32,
    Other,
}

internal data class RppgTensorSchema(
    val name: String,
    val type: RppgTensorType,
    val shape: LongArray,
)

internal data class RppgTensorState(
    val data: FloatArray,
    val shape: LongArray,
) {
    fun copy() = RppgTensorState(data.copyOf(), shape.copyOf())
}

/** Owns copies of the recurrent tensors so reset cannot reuse mutated arrays. */
internal class RppgRecurrentState(initial: LinkedHashMap<String, RppgTensorState>) {
    private val initial = copyState(initial)
    var current: LinkedHashMap<String, RppgTensorState> = copyState(initial)
        private set

    fun reset() {
        current = copyState(initial)
    }

    fun replace(next: LinkedHashMap<String, RppgTensorState>) {
        require(next.keys == initial.keys) { "rPPG recurrent state keys changed during inference" }
        current = copyState(next)
    }

    private fun copyState(source: Map<String, RppgTensorState>) = linkedMapOf<String, RppgTensorState>().apply {
        source.forEach { (name, value) -> put(name, value.copy()) }
    }
}

/** Runtime schema checks for the pinned ME-rPPG recurrent ONNX contract. */
internal object RppgModelContract {
    const val IMAGE_INPUT_NAME = "arg_0.1"
    const val DELTA_INPUT_NAME = "onnx::Mul_37"
    const val RECURRENT_STATE_COUNT = 36

    fun validate(
        inputs: Map<String, RppgTensorSchema>,
        outputs: List<RppgTensorSchema>,
        initialState: Map<String, RppgTensorState>,
    ) {
        val image = requireNotNull(inputs[IMAGE_INPUT_NAME]) { "rPPG image input is missing" }
        require(image.type == RppgTensorType.Float32) { "rPPG image input must be float32" }
        require(image.shape.contentEquals(RppgImagePreprocessor.MODEL_INPUT_SHAPE)) {
            "Unexpected rPPG image shape: ${image.shape.contentToString()}"
        }

        val delta = requireNotNull(inputs[DELTA_INPUT_NAME]) { "rPPG delta input is missing" }
        require(delta.type == RppgTensorType.Float32) { "rPPG delta input must be float32" }
        require(delta.shape.isEmpty()) {
            "rPPG delta input must be a scalar, got ${delta.shape.contentToString()}"
        }

        require(initialState.size == RECURRENT_STATE_COUNT) {
            "Expected $RECURRENT_STATE_COUNT rPPG recurrent tensors, got ${initialState.size}"
        }
        val modelStateNames = inputs.keys - setOf(IMAGE_INPUT_NAME, DELTA_INPUT_NAME)
        require(modelStateNames.size == RECURRENT_STATE_COUNT) {
            "Expected $RECURRENT_STATE_COUNT model recurrent inputs, got ${modelStateNames.size}"
        }
        require(modelStateNames == initialState.keys) {
            "rPPG state.json keys do not match model recurrent inputs"
        }
        initialState.forEach { (name, state) ->
            val input = requireNotNull(inputs[name]) { "Missing rPPG state input: $name" }
            require(input.type == RppgTensorType.Float32) { "rPPG state $name must be float32" }
            require(input.shape.contentEquals(state.shape)) {
                "rPPG state $name shape differs from model input"
            }
            require(state.data.size == elementCount(state.shape)) {
                "rPPG state $name data length differs from its shape"
            }
        }

        require(outputs.size >= RECURRENT_STATE_COUNT + 1) {
            "Expected BVP plus $RECURRENT_STATE_COUNT rPPG state outputs, got ${outputs.size}"
        }
        val bvp = outputs.first()
        require(bvp.type == RppgTensorType.Float32) { "rPPG BVP output must be float32" }
        require(bvp.shape.lastOrNull() == 1L) { "Unexpected rPPG BVP output shape" }
        initialState.values.zip(outputs.drop(1)).forEach { (state, output) ->
            require(output.type == RppgTensorType.Float32) { "rPPG recurrent output must be float32" }
            require(compatibleShape(state.shape, output.shape)) {
                "rPPG recurrent output ${output.name} does not match its state shape"
            }
        }
    }

    private fun compatibleShape(expected: LongArray, actual: LongArray): Boolean =
        expected.size == actual.size && expected.indices.all { index ->
            actual[index] < 0L || actual[index] == expected[index]
        }

    private fun elementCount(shape: LongArray): Int =
        shape.fold(1L) { product, dimension -> product * dimension }.also {
            require(it in 0..Int.MAX_VALUE) { "rPPG tensor is too large" }
        }.toInt()
}
