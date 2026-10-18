package com.vvewell.health.core.rppg

import kotlin.math.floor
import kotlin.math.min

/**
 * Converts CameraX ARGB pixels into the channels-last tensor expected by the
 * ME-rPPG model. Keeping this independent of Bitmap makes the input contract
 * unit-testable on the JVM.
 */
internal object RppgImagePreprocessor {
    const val MODEL_SIZE = 36
    val MODEL_INPUT_SHAPE = longArrayOf(1L, 1L, MODEL_SIZE.toLong(), MODEL_SIZE.toLong(), 3L)

    fun toModelInput(
        argb: IntArray,
        width: Int,
        height: Int,
        rotationDegrees: Int,
    ): FloatArray {
        val rotated = uprightFrame(argb, width, height, rotationDegrees)
        val cropSize = min(rotated.width, rotated.height)
        val cropLeft = (rotated.width - cropSize) / 2
        val cropTop = (rotated.height - cropSize) / 2
        return toModelInput(
            frame = rotated,
            roi = RppgRectF(
                left = cropLeft.toFloat(),
                top = cropTop.toFloat(),
                right = (cropLeft + cropSize).toFloat(),
                bottom = (cropTop + cropSize).toFloat(),
            ),
        )
    }

    fun uprightFrame(
        argb: IntArray,
        width: Int,
        height: Int,
        rotationDegrees: Int,
    ): RppgArgbFrame = rotateArgb(argb, width, height, rotationDegrees)

    fun toModelInput(frame: RppgArgbFrame, roi: RppgRectF): FloatArray {
        val clampedRoi = requireNotNull(roi.clamp(frame.width, frame.height)) {
            "rPPG face ROI does not intersect the upright image"
        }
        val result = FloatArray(MODEL_SIZE * MODEL_SIZE * CHANNELS)

        for (y in 0 until MODEL_SIZE) {
            val sourceY = clampedRoi.top +
                ((y + 0.5) * clampedRoi.height / MODEL_SIZE - 0.5)
            for (x in 0 until MODEL_SIZE) {
                val sourceX = clampedRoi.left +
                    ((x + 0.5) * clampedRoi.width / MODEL_SIZE - 0.5)
                val color = bilinearSample(frame, clampedRoi, sourceX, sourceY)
                val offset = (y * MODEL_SIZE + x) * CHANNELS
                result[offset] = ((color shr 16) and 0xFF) / 255f
                result[offset + 1] = ((color shr 8) and 0xFF) / 255f
                result[offset + 2] = (color and 0xFF) / 255f
            }
        }
        return result
    }

    fun normalizeArgbPixelsToRgb(argb: IntArray): FloatArray {
        val result = FloatArray(argb.size * CHANNELS)
        argb.forEachIndexed { index, color ->
            val offset = index * CHANNELS
            result[offset] = ((color shr 16) and 0xFF) / 255f
            result[offset + 1] = ((color shr 8) and 0xFF) / 255f
            result[offset + 2] = (color and 0xFF) / 255f
        }
        return result
    }

    fun rotateArgb(
        argb: IntArray,
        width: Int,
        height: Int,
        rotationDegrees: Int,
    ): RppgArgbFrame {
        require(width > 0 && height > 0) { "rPPG image dimensions must be positive" }
        require(argb.size == width * height) { "rPPG ARGB buffer does not match image dimensions" }

        return when (normalizeRotation(rotationDegrees)) {
            0 -> RppgArgbFrame(argb.copyOf(), width, height)
            90 -> {
                val output = IntArray(argb.size)
                for (sourceY in 0 until height) {
                    for (sourceX in 0 until width) {
                        val destinationX = height - 1 - sourceY
                        val destinationY = sourceX
                        output[destinationY * height + destinationX] = argb[sourceY * width + sourceX]
                    }
                }
                RppgArgbFrame(output, height, width)
            }
            180 -> {
                val output = IntArray(argb.size)
                for (sourceY in 0 until height) {
                    for (sourceX in 0 until width) {
                        val destinationX = width - 1 - sourceX
                        val destinationY = height - 1 - sourceY
                        output[destinationY * width + destinationX] = argb[sourceY * width + sourceX]
                    }
                }
                RppgArgbFrame(output, width, height)
            }
            270 -> {
                val output = IntArray(argb.size)
                for (sourceY in 0 until height) {
                    for (sourceX in 0 until width) {
                        val destinationX = sourceY
                        val destinationY = width - 1 - sourceX
                        output[destinationY * height + destinationX] = argb[sourceY * width + sourceX]
                    }
                }
                RppgArgbFrame(output, height, width)
            }
            else -> error("normalizeRotation only returns right-angle rotations")
        }
    }

    private fun bilinearSample(
        frame: RppgArgbFrame,
        roi: RppgRectF,
        x: Double,
        y: Double,
    ): Int {
        val sampleX = x.coerceIn(
            roi.left.toDouble(),
            (roi.right - 1f).coerceAtLeast(roi.left).toDouble(),
        )
        val sampleY = y.coerceIn(
            roi.top.toDouble(),
            (roi.bottom - 1f).coerceAtLeast(roi.top).toDouble(),
        )
        val left = floor(sampleX).toInt().coerceIn(0, frame.width - 1)
        val top = floor(sampleY).toInt().coerceIn(0, frame.height - 1)
        val right = (left + 1).coerceAtMost(frame.width - 1)
        val bottom = (top + 1).coerceAtMost(frame.height - 1)
        val horizontal = (sampleX - floor(sampleX)).toFloat().coerceIn(0f, 1f)
        val vertical = (sampleY - floor(sampleY)).toFloat().coerceIn(0f, 1f)
        val topLeft = frame.argb[top * frame.width + left]
        val topRight = frame.argb[top * frame.width + right]
        val bottomLeft = frame.argb[bottom * frame.width + left]
        val bottomRight = frame.argb[bottom * frame.width + right]

        fun channel(shift: Int): Int {
            val topValue = ((topLeft shr shift) and 0xFF) * (1f - horizontal) +
                ((topRight shr shift) and 0xFF) * horizontal
            val bottomValue = ((bottomLeft shr shift) and 0xFF) * (1f - horizontal) +
                ((bottomRight shr shift) and 0xFF) * horizontal
            return (topValue * (1f - vertical) + bottomValue * vertical).toInt().coerceIn(0, 255)
        }

        return (0xFF shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
    }

    private fun normalizeRotation(rotationDegrees: Int): Int {
        val normalized = ((rotationDegrees % 360) + 360) % 360
        require(normalized in setOf(0, 90, 180, 270)) {
            "Unsupported rPPG rotation: $rotationDegrees"
        }
        return normalized
    }

    private const val CHANNELS = 3
}

internal data class RppgArgbFrame(
    val argb: IntArray,
    val width: Int,
    val height: Int,
)
