package com.vvewell.health.core.rppg

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class RppgImagePreprocessorTest {
    @Test
    fun normalizesArgbChannelsToZeroOneRgb() {
        val values = RppgImagePreprocessor.normalizeArgbPixelsToRgb(
            intArrayOf(
                color(0, 0, 0),
                color(128, 64, 32),
                color(255, 255, 255),
            ),
        )

        assertEquals(0f, values[0], 0f)
        assertEquals(128f / 255f, values[3], 1e-6f)
        assertEquals(64f / 255f, values[4], 1e-6f)
        assertEquals(32f / 255f, values[5], 1e-6f)
        assertEquals(1f, values[8], 0f)
        assertTrue(values.all { it in 0f..1f })
    }

    @Test
    fun preparesChannelsLastRgbTensorWithoutSwappingChannels() {
        val pixels = IntArray(RppgImagePreprocessor.MODEL_SIZE * RppgImagePreprocessor.MODEL_SIZE) {
            color(17, 34, 51)
        }

        val result = RppgImagePreprocessor.toModelInput(
            pixels,
            RppgImagePreprocessor.MODEL_SIZE,
            RppgImagePreprocessor.MODEL_SIZE,
            0,
        )

        assertEquals(RppgImagePreprocessor.MODEL_SIZE * RppgImagePreprocessor.MODEL_SIZE * 3, result.size)
        assertArrayEquals(longArrayOf(1, 1, 36, 36, 3), RppgImagePreprocessor.MODEL_INPUT_SHAPE)
        assertEquals(17f / 255f, result[0], 1e-6f)
        assertEquals(34f / 255f, result[1], 1e-6f)
        assertEquals(51f / 255f, result[2], 1e-6f)
    }

    @Test
    fun rotatesArgbFramesAtEveryCameraXRightAngle() {
        val red = color(255, 0, 0)
        val green = color(0, 255, 0)
        val blue = color(0, 0, 255)
        val white = color(255, 255, 255)
        val yellow = color(255, 255, 0)
        val cyan = color(0, 255, 255)
        val source = intArrayOf(red, green, blue, white, yellow, cyan)

        val right = RppgImagePreprocessor.rotateArgb(source, 2, 3, 90)
        assertEquals(3, right.width)
        assertEquals(2, right.height)
        assertArrayEquals(intArrayOf(yellow, blue, red, cyan, white, green), right.argb)

        val halfTurn = RppgImagePreprocessor.rotateArgb(source, 2, 3, 180)
        assertEquals(2, halfTurn.width)
        assertEquals(3, halfTurn.height)
        assertArrayEquals(intArrayOf(cyan, yellow, white, blue, green, red), halfTurn.argb)

        val left = RppgImagePreprocessor.rotateArgb(source, 2, 3, 270)
        assertEquals(3, left.width)
        assertEquals(2, left.height)
        assertArrayEquals(intArrayOf(green, white, cyan, red, blue, yellow), left.argb)
    }

    @Test
    fun resizesAnOffCenterFaceRoiWithoutFallingBackToTheCenter() {
        val blue = color(0, 0, 255)
        val red = color(255, 0, 0)
        val frame = RppgArgbFrame(
            argb = intArrayOf(
                blue, blue, blue, red, red, red,
                blue, blue, blue, red, red, red,
                blue, blue, blue, red, red, red,
                blue, blue, blue, red, red, red,
            ),
            width = 6,
            height = 4,
        )

        val result = RppgImagePreprocessor.toModelInput(
            frame = frame,
            roi = RppgRectF(left = 3f, top = 0f, right = 6f, bottom = 4f),
        )

        assertEquals(RppgImagePreprocessor.MODEL_SIZE * RppgImagePreprocessor.MODEL_SIZE * 3, result.size)
        assertEquals(1f, result[0], 0f)
        assertEquals(0f, result[1], 0f)
        assertEquals(0f, result[2], 0f)
        assertTrue(result.indices.step(3).all { abs(result[it] - 1f) <= 1f / 255f + 1e-6f })
    }

    private fun color(red: Int, green: Int, blue: Int): Int =
        (0xFF shl 24) or (red shl 16) or (green shl 8) or blue
}
