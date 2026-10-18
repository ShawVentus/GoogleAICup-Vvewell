package com.vvewell.health.core.rppg

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class RppgModelContractTest {
    @Test
    fun acceptsPinnedImageDeltaAndRecurrentStateSchema() {
        RppgModelContract.validate(validInputs(), validOutputs(), validState())
    }

    @Test
    fun rejectsSchemaWhenImageShapeOrStateCountDoesNotMatch() {
        val wrongImageShape = validInputs().also {
            it[RppgModelContract.IMAGE_INPUT_NAME] = RppgTensorSchema(
                RppgModelContract.IMAGE_INPUT_NAME,
                RppgTensorType.Float32,
                longArrayOf(1, 1, 36, 3, 36),
            )
        }
        assertSchemaFailure {
            RppgModelContract.validate(wrongImageShape, validOutputs(), validState())
        }

        val incompleteState = validState().also { it.remove("state-35") }
        assertSchemaFailure {
            RppgModelContract.validate(validInputs(), validOutputs(), incompleteState)
        }
    }

    @Test
    fun resetRestoresIndependentInitialRecurrentStateCopies() {
        val initial = linkedMapOf(
            "first" to RppgTensorState(floatArrayOf(1f, 2f), longArrayOf(2)),
            "second" to RppgTensorState(floatArrayOf(3f), longArrayOf(1)),
        )
        val state = RppgRecurrentState(initial)
        initial.getValue("first").data[0] = 99f
        state.replace(
            linkedMapOf(
                "first" to RppgTensorState(floatArrayOf(7f, 8f), longArrayOf(2)),
                "second" to RppgTensorState(floatArrayOf(9f), longArrayOf(1)),
            ),
        )

        state.reset()

        assertArrayEquals(floatArrayOf(1f, 2f), state.current.getValue("first").data, 0f)
        assertArrayEquals(floatArrayOf(3f), state.current.getValue("second").data, 0f)
    }

    private fun validInputs(): LinkedHashMap<String, RppgTensorSchema> = linkedMapOf<String, RppgTensorSchema>().apply {
        put(
            RppgModelContract.IMAGE_INPUT_NAME,
            RppgTensorSchema(
                RppgModelContract.IMAGE_INPUT_NAME,
                RppgTensorType.Float32,
                longArrayOf(1, 1, 36, 36, 3),
            ),
        )
        put(
            RppgModelContract.DELTA_INPUT_NAME,
            RppgTensorSchema(RppgModelContract.DELTA_INPUT_NAME, RppgTensorType.Float32, longArrayOf()),
        )
        validState().forEach { (name, value) ->
            put(name, RppgTensorSchema(name, RppgTensorType.Float32, value.shape))
        }
    }

    private fun validOutputs(): List<RppgTensorSchema> = buildList {
        add(RppgTensorSchema("bvp", RppgTensorType.Float32, longArrayOf(-1, 1)))
        validState().forEach { (name, value) ->
            add(RppgTensorSchema("next-$name", RppgTensorType.Float32, value.shape))
        }
    }

    private fun validState(): LinkedHashMap<String, RppgTensorState> =
        linkedMapOf<String, RppgTensorState>().apply {
            repeat(RppgModelContract.RECURRENT_STATE_COUNT) { index ->
                val name = "state-$index"
                put(name, RppgTensorState(floatArrayOf(index.toFloat()), longArrayOf(1)))
            }
        }

    private fun assertSchemaFailure(block: () -> Unit) {
        val error = runCatching(block).exceptionOrNull()
        assertTrue(error is IllegalArgumentException)
    }
}
