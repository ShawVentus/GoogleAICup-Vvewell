package com.vvewell.health.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.view.PreviewView
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.Air
import androidx.compose.material.icons.outlined.Bloodtype
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.SignalCellularAlt
import androidx.compose.material.icons.outlined.Timeline
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathFillType
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.vvewell.health.core.rppg.MetricEstimate
import com.vvewell.health.core.rppg.RppgCameraController
import com.vvewell.health.core.rppg.RppgConfidenceLabel
import com.vvewell.health.core.rppg.RppgConfidencePolicy
import com.vvewell.health.core.rppg.RppgEstimateSnapshot
import com.vvewell.health.core.rppg.RppgMeasurementState
import com.vvewell.health.core.rppg.RppgPhase
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlinx.coroutines.delay
import kotlin.math.min

@Composable
fun RppgScreen(
    onBack: () -> Unit,
    onStateChanged: (RppgMeasurementState) -> Unit = {},
    onEstimate: (RppgEstimateSnapshot) -> Unit = {},
    onTerminalState: (RppgMeasurementState) -> Unit = {},
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var state by remember { mutableStateOf(RppgMeasurementState()) }
    var completedAt by remember { mutableStateOf<LocalDateTime?>(null) }
    val terminalStateReported = remember { mutableStateOf(false) }
    val currentState by rememberUpdatedState(state)
    val currentOnStateChanged by rememberUpdatedState(onStateChanged)
    val currentOnEstimate by rememberUpdatedState(onEstimate)
    val currentOnTerminalState by rememberUpdatedState(onTerminalState)
    val timerElapsedMillis = remember { mutableLongStateOf(0L) }
    val previewView = remember {
        PreviewView(context).apply {
            scaleType = PreviewView.ScaleType.FILL_CENTER
        }
    }
    val controller = remember {
        RppgCameraController(
            context = context,
            lifecycleOwner = lifecycleOwner,
            previewView = previewView,
            onState = { next ->
                currentOnStateChanged(next)
                if (next.phase.isResultPhase() && !terminalStateReported.value) {
                    terminalStateReported.value = true
                    completedAt = LocalDateTime.now()
                    currentOnTerminalState(next)
                } else if (next.phase == RppgPhase.PreviewPreparing) {
                    terminalStateReported.value = false
                    completedAt = null
                }
                timerElapsedMillis.longValue = when (next.phase) {
                    RppgPhase.Completed, RppgPhase.LowQuality ->
                        RppgMeasurementState.MEASUREMENT_MILLIS
                    RppgPhase.Aligning, RppgPhase.Collecting, RppgPhase.Estimating ->
                        next.elapsedMillis
                    else -> 0L
                }
                val nonTimingState = next.copy(elapsedMillis = 0L)
                if (currentState != nonTimingState) state = nonTimingState
            },
            onEstimate = { currentOnEstimate(it) },
        )
    }
    DisposableEffect(controller) {
        onDispose(controller::close)
    }
    LaunchedEffect(state.pipelineActive) {
        while (state.pipelineActive) {
            controller.tick()
            delay(RppgVisual.TICK_MILLIS)
        }
    }

    fun exit() {
        if (state.pipelineActive) controller.cancel()
        onBack()
    }
    BackHandler(onBack = ::exit)

    var startAfterPermission by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            if (startAfterPermission) controller.requestMeasurement() else controller.preparePreview()
        } else {
            controller.permissionDenied()
        }
        startAfterPermission = false
    }
    LaunchedEffect(Unit) {
        if (
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            controller.preparePreview()
        } else {
            startAfterPermission = false
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }
    fun startMeasurement() {
        if (
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            controller.requestMeasurement()
        } else {
            startAfterPermission = true
            permissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    if (state.phase.isResultPhase()) {
        RppgResultScreen(
            state = state,
            completedAt = completedAt,
            onBack = ::exit,
            onRetry = ::startMeasurement,
        )
    } else {
        RppgMeasurementScreen(
            state = state,
            previewView = previewView,
            elapsedMillis = { timerElapsedMillis.longValue },
            onBack = ::exit,
            onCancel = controller::cancel,
            onStart = ::startMeasurement,
        )
    }
}

@Composable
private fun RppgMeasurementScreen(
    state: RppgMeasurementState,
    previewView: PreviewView,
    elapsedMillis: () -> Long,
    onBack: () -> Unit,
    onCancel: () -> Unit,
    onStart: () -> Unit,
) {
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .background(RppgVisual.PREVIEW_FALLBACK),
    ) {
        val compact = maxHeight < RppgVisual.COMPACT_HEIGHT_THRESHOLD
        val guideAspectRatio = if (compact) {
            RppgVisual.COMPACT_GUIDE_ASPECT_RATIO
        } else {
            RppgVisual.GUIDE_ASPECT_RATIO
        }
        val guideTopReserve = maxHeight * if (compact) {
            RppgVisual.COMPACT_TOP_RESERVED_FRACTION
        } else {
            RppgVisual.TOP_RESERVED_FRACTION
        }
        val guideBottomReserve = maxHeight * RppgVisual.BOTTOM_RESERVED_FRACTION
        val guideAreaHeight = maxHeight - guideTopReserve - guideBottomReserve
        val desiredGuideWidth = maxWidth * RppgVisual.GUIDE_WIDTH_FRACTION
        val desiredGuideHeight = desiredGuideWidth / guideAspectRatio
        val guideHeight = min(desiredGuideHeight.value, guideAreaHeight.value).dp
        val guideWidth = guideHeight * guideAspectRatio
        val guideOffset = guideTopReserve +
            (guideAreaHeight - guideHeight) * RppgVisual.GUIDE_VERTICAL_BIAS
        val guideGeometry = FaceGuideGeometry(
            width = guideWidth,
            height = guideHeight,
            offsetY = guideOffset,
        )

        AndroidView(
            factory = { previewView },
            modifier = Modifier.fillMaxSize(),
        )

        FaceFocusMask(
            geometry = guideGeometry,
            modifier = Modifier.fillMaxSize(),
        )

        Canvas(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = guideGeometry.offsetY)
                .size(width = guideGeometry.width, height = guideGeometry.height),
        ) {
            val inset = RppgVisual.GUIDE_STROKE_WIDTH.toPx()
            drawOval(
                color = RppgVisual.GUIDE_COLOR,
                topLeft = Offset(inset, inset),
                size = Size(size.width - inset * 2, size.height - inset * 2),
                style = Stroke(width = inset),
            )
        }

        MeasurementTopOverlay(
            state = state,
            compact = compact,
            onBack = onBack,
            onCancel = onCancel,
            modifier = Modifier.align(Alignment.TopCenter),
        )
        MeasurementBottomOverlay(
            state = state,
            elapsedMillis = elapsedMillis,
            onStart = onStart,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

/**
 * Stable visual fallback for PreviewView's default PERFORMANCE mode.
 *
 * CameraX uses a SurfaceView when possible in this mode, so its pixels do not
 * reliably participate in a parent RenderEffect. This layer never samples or
 * copies camera frames: it only lowers contrast outside the shared guide oval.
 */
@Composable
private fun FaceFocusMask(
    geometry: FaceGuideGeometry,
    modifier: Modifier = Modifier,
) {
    Canvas(modifier = modifier) {
        val guideWidth = geometry.width.toPx()
        val guideHeight = geometry.height.toPx()
        val guideRect = Rect(
            left = (size.width - guideWidth) / 2f,
            top = geometry.offsetY.toPx(),
            right = (size.width + guideWidth) / 2f,
            bottom = geometry.offsetY.toPx() + guideHeight,
        )
        val clearGuideRect = guideRect.expandBy(-RppgVisual.GUIDE_STROKE_WIDTH.toPx())
        val featherWidth = RppgVisual.FOCUS_FEATHER_WIDTH.toPx()
        val expandedGuide = clearGuideRect.expandBy(featherWidth)
        val fullBounds = Rect(Offset.Zero, size)

        drawPath(
            path = outsideOvalPath(fullBounds, expandedGuide),
            color = RppgVisual.OUTSIDE_FOCUS_MASK,
        )

        val bandWidth = featherWidth / RppgVisual.FOCUS_FEATHER_STEPS
        repeat(RppgVisual.FOCUS_FEATHER_STEPS) { index ->
            val inner = clearGuideRect.expandBy(index * bandWidth)
            val outer = clearGuideRect.expandBy((index + 1) * bandWidth)
            val transition = (index + 1f) / RppgVisual.FOCUS_FEATHER_STEPS
            drawPath(
                path = ovalBandPath(inner, outer),
                color = RppgVisual.OUTSIDE_FOCUS_BASE.copy(
                    alpha = RppgVisual.OUTSIDE_FOCUS_ALPHA * transition,
                ),
            )
        }
    }
}

private fun outsideOvalPath(bounds: Rect, clearOval: Rect): Path =
    Path().apply {
        fillType = PathFillType.EvenOdd
        addRect(bounds)
        addOval(clearOval)
    }

private fun ovalBandPath(inner: Rect, outer: Rect): Path =
    Path().apply {
        fillType = PathFillType.EvenOdd
        addOval(outer)
        addOval(inner)
    }

private fun Rect.expandBy(distance: Float): Rect = Rect(
    left = left - distance,
    top = top - distance,
    right = right + distance,
    bottom = bottom + distance,
)

@Composable
private fun MeasurementTopOverlay(
    state: RppgMeasurementState,
    compact: Boolean,
    onBack: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(
                        RppgVisual.TOP_GRADIENT_STRONG,
                        RppgVisual.TOP_GRADIENT_MID,
                        Color.Transparent,
                    ),
                ),
            )
            .padding(
                start = RppgVisual.SCREEN_HORIZONTAL_PADDING,
                end = RppgVisual.SCREEN_HORIZONTAL_PADDING,
                top = RppgVisual.TOP_PADDING,
                bottom = if (compact) 20.dp else 34.dp,
            ),
    ) {
        RppgNavigationBar(
            title = "AI 健康自测",
            onBack = onBack,
            trailing = {
                if (state.measuring) {
                    TextButton(
                        onClick = onCancel,
                        modifier = Modifier.background(
                            RppgVisual.CONTROL_SURFACE,
                            RoundedCornerShape(RppgVisual.CONTROL_RADIUS),
                        ),
                    ) {
                        Text("取消", color = Color.White)
                    }
                }
            },
        )
        if (!compact) {
            Spacer(Modifier.height(12.dp))
            Text(
                "呼吸与心跳测量",
                modifier = Modifier.fillMaxWidth(),
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
        }
        Spacer(Modifier.height(if (compact) 8.dp else 12.dp))
        UnifiedVitalsStrip(state)
    }
}

@Composable
private fun UnifiedVitalsStrip(state: RppgMeasurementState) {
    val heartRate = state.heartRateEstimate.displayValue()
    val respiration = state.respirationEstimate.displayValue()
    val signalQuality = RppgConfidencePolicy.conservativeAggregateQuality(
        state.heartRateEstimate,
        state.respirationEstimate,
    ).times(100)
        .toInt()
        .toString()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(RppgVisual.INFO_SURFACE, RoundedCornerShape(RppgVisual.INFO_RADIUS))
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LiveVital(
            label = "心率",
            value = heartRate,
            unit = "BPM",
            modifier = Modifier.weight(1f),
        )
        VitalsDivider()
        LiveVital(
            label = "呼吸率",
            value = respiration,
            unit = "次/分",
            modifier = Modifier.weight(1f),
        )
        VitalsDivider()
        LiveVital(
            label = "信号质量",
            value = signalQuality,
            unit = "%",
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun LiveVital(
    label: String,
    value: String,
    unit: String,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            label,
            color = Color.White.copy(alpha = 0.68f),
            style = MaterialTheme.typography.labelSmall,
        )
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(
                value,
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                unit,
                color = Color.White.copy(alpha = 0.58f),
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}

@Composable
private fun VitalsDivider() {
    Box(
        modifier = Modifier
            .width(1.dp)
            .height(34.dp)
            .background(Color.White.copy(alpha = 0.12f)),
    )
}

@Composable
private fun MeasurementBottomOverlay(
    state: RppgMeasurementState,
    elapsedMillis: () -> Long,
    onStart: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(
                        Color.Transparent,
                        RppgVisual.BOTTOM_GRADIENT_MID,
                        RppgVisual.BOTTOM_GRADIENT_STRONG,
                    ),
                ),
            )
            .padding(
                start = RppgVisual.SCREEN_HORIZONTAL_PADDING,
                end = RppgVisual.SCREEN_HORIZONTAL_PADDING,
                top = 46.dp,
                bottom = RppgVisual.BOTTOM_PADDING,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            state.measurementHeadline(),
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            state.measurementInstruction(),
            color = Color.White.copy(alpha = 0.72f),
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center,
        )
        MeasurementTimer(
            running = state.measuring,
            elapsedMillis = elapsedMillis,
        )
        if (state.canRequestStart || state.phase == RppgPhase.Ready) {
            Spacer(Modifier.height(16.dp))
            Button(
                onClick = onStart,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(RppgVisual.PRIMARY_BUTTON_HEIGHT),
                colors = ButtonDefaults.buttonColors(containerColor = RppgVisual.ACCENT),
                shape = RoundedCornerShape(RppgVisual.PRIMARY_BUTTON_RADIUS),
            ) {
                Text(
                    if (
                        state.phase == RppgPhase.PermissionDenied ||
                        state.phase == RppgPhase.Cancelled
                    ) {
                        "重新测量"
                    } else {
                        "开始 20 秒测量"
                    },
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun MeasurementTimer(
    running: Boolean,
    elapsedMillis: () -> Long,
) {
    if (!running) return

    val elapsed = elapsedMillis()
    val targetProgress = (
        elapsed / RppgMeasurementState.MEASUREMENT_MILLIS.toFloat()
        ).coerceIn(0f, 1f)
    val animatedProgress by animateFloatAsState(
        targetValue = targetProgress,
        animationSpec = tween(
            durationMillis = RppgVisual.TIMER_PROGRESS_ANIMATION_MILLIS,
            easing = LinearEasing,
        ),
        label = "rPPG measurement progress",
    )
    val elapsedSeconds = (elapsed / 1_000L)
        .coerceIn(0L, RppgMeasurementState.MEASUREMENT_MILLIS / 1_000L)

    Spacer(Modifier.height(14.dp))
    Text(
        "正在检测 $elapsedSeconds / 20 秒",
        color = Color.White.copy(alpha = 0.9f),
        style = MaterialTheme.typography.labelLarge,
    )
    Spacer(Modifier.height(8.dp))
    LinearProgressIndicator(
        progress = { animatedProgress },
        modifier = Modifier
            .fillMaxWidth()
            .height(RppgVisual.PROGRESS_HEIGHT),
        color = Color.White,
        trackColor = Color.White.copy(alpha = 0.24f),
    )
}

@Composable
private fun RppgResultScreen(
    state: RppgMeasurementState,
    completedAt: LocalDateTime?,
    onBack: () -> Unit,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(RppgVisual.RESULT_BACKGROUND)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = RppgVisual.RESULT_HORIZONTAL_PADDING),
    ) {
        RppgNavigationBar(
            title = "检测结果",
            onBack = onBack,
            modifier = Modifier.padding(top = RppgVisual.TOP_PADDING),
        )
        Spacer(Modifier.height(30.dp))
        ResultOverview(state = state, completedAt = completedAt)
        Spacer(Modifier.height(34.dp))
        ResultSectionTitle("生命体征")
        ResultMetricRow(
            icon = Icons.Filled.Favorite,
            iconColor = RppgVisual.HEART_COLOR,
            label = "心率",
            value = state.heartRateEstimate.displayValue(),
            unit = "bpm",
            badge = state.heartRateEstimate.confidenceBadge(),
            badgeTone = state.heartRateEstimate.confidenceBadgeTone(),
        )
        ResultMetricRow(
            icon = Icons.Outlined.Air,
            iconColor = RppgVisual.RESPIRATION_COLOR,
            label = "呼吸率",
            value = state.respirationEstimate.displayValue(),
            unit = "次/分",
            badge = state.respirationEstimate.confidenceBadge(),
            badgeTone = state.respirationEstimate.confidenceBadgeTone(),
        )
        val syntheticVitals = state.syntheticVitals.takeIf { state.phase == RppgPhase.Completed }
        syntheticVitals?.let { demo ->
            ResultMetricRow(
                icon = Icons.Outlined.Bloodtype,
                iconColor = RppgVisual.OXYGEN_COLOR,
                label = "血氧",
                value = demo.demoSpO2.toString(),
                unit = "%",
                badge = "内部演示数据",
                badgeTone = BadgeTone.Neutral,
            )
        }
        Spacer(Modifier.height(28.dp))
        ResultSectionTitle("压力与信号")
        syntheticVitals?.let { demo ->
            ResultMetricRow(
                icon = Icons.Outlined.Bolt,
                iconColor = RppgVisual.STRESS_COLOR,
                label = "压力状态",
                value = demo.demoStressStatus.displayName,
                unit = "",
                badge = "内部演示数据",
                badgeTone = BadgeTone.Neutral,
            )
        }
        val signalQuality = RppgConfidencePolicy.conservativeAggregateQuality(
            state.heartRateEstimate,
            state.respirationEstimate,
        )
        ResultMetricRow(
            icon = Icons.Outlined.SignalCellularAlt,
            iconColor = RppgVisual.SIGNAL_COLOR,
            label = "信号质量",
            value = signalQuality.times(100).toInt().toString(),
            unit = "%",
            badge = signalQuality.qualityLabel(),
            badgeTone = if (signalQuality < RppgConfidencePolicy.HIGH_CONFIDENCE_THRESHOLD) {
                BadgeTone.Caution
            } else {
                BadgeTone.Positive
            },
        )
        Spacer(Modifier.height(28.dp))
        ResultSectionTitle("更多数据")
        ResultMetricRow(
            icon = Icons.Outlined.Timeline,
            iconColor = RppgVisual.RMSSD_COLOR,
            label = "RMSSD",
            value = state.result?.rmssdMs?.toInt()?.toString() ?: "--",
            unit = "ms",
            badge = state.result?.rmssdMs?.let { "参考" },
            badgeTone = BadgeTone.Neutral,
            showDivider = false,
        )
        Spacer(Modifier.height(30.dp))
        Button(
            onClick = onRetry,
            modifier = Modifier
                .fillMaxWidth()
                .height(RppgVisual.PRIMARY_BUTTON_HEIGHT),
            colors = ButtonDefaults.buttonColors(containerColor = RppgVisual.ACCENT),
            shape = RoundedCornerShape(RppgVisual.PRIMARY_BUTTON_RADIUS),
        ) {
            Text(
                if (state.phase == RppgPhase.Completed) "再次测量" else "重新测量",
                fontWeight = FontWeight.SemiBold,
            )
        }
        Spacer(Modifier.height(RppgVisual.RESULT_BOTTOM_SPACING))
    }
}

@Composable
private fun RppgNavigationBar(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit = {},
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(RppgVisual.NAVIGATION_HEIGHT),
        contentAlignment = Alignment.Center,
    ) {
        IconButton(
            onClick = onBack,
            modifier = Modifier
                .align(Alignment.CenterStart)
                .size(RppgVisual.NAVIGATION_CONTROL_SIZE)
                .background(RppgVisual.CONTROL_SURFACE, CircleShape),
        ) {
            Icon(
                Icons.AutoMirrored.Outlined.ArrowBack,
                contentDescription = "返回",
                tint = Color.White,
            )
        }
        Text(
            title,
            color = Color.White,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Box(modifier = Modifier.align(Alignment.CenterEnd)) {
            trailing()
        }
    }
}

@Composable
private fun ResultOverview(
    state: RppgMeasurementState,
    completedAt: LocalDateTime?,
) {
    val appearance = state.resultAppearance()
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(
            imageVector = appearance.icon,
            contentDescription = null,
            tint = appearance.color,
            modifier = Modifier.size(52.dp),
        )
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                appearance.title,
                color = Color.White,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
            completedAt?.let {
                Text(
                    RESULT_TIME_FORMATTER.format(it),
                    color = RppgVisual.RESULT_SECONDARY_TEXT,
                    style = MaterialTheme.typography.bodyLarge,
                )
            }
            if (state.phase == RppgPhase.Error) {
                Text(
                    "请返回或重新测量",
                    color = RppgVisual.RESULT_SECONDARY_TEXT,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }
    }
}

@Composable
private fun ResultSectionTitle(title: String) {
    Text(
        title,
        color = RppgVisual.RESULT_SECTION_TEXT,
        style = MaterialTheme.typography.titleMedium,
        fontWeight = FontWeight.Medium,
    )
    Spacer(Modifier.height(12.dp))
}

@Composable
private fun ResultMetricRow(
    icon: ImageVector,
    iconColor: Color,
    label: String,
    value: String,
    unit: String,
    badge: String? = null,
    badgeTone: BadgeTone = BadgeTone.Positive,
    showDivider: Boolean = true,
) {
    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = RppgVisual.RESULT_ROW_MIN_HEIGHT)
                .padding(vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                icon,
                contentDescription = null,
                tint = iconColor,
                modifier = Modifier.size(28.dp),
            )
            Spacer(Modifier.width(16.dp))
            Text(
                label,
                modifier = Modifier.weight(1f),
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
            )
            Column(
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(5.dp),
                ) {
                    Text(
                        value,
                        color = Color.White,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    if (unit.isNotBlank()) {
                        Text(
                            unit,
                            color = RppgVisual.RESULT_SECONDARY_TEXT,
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                }
                badge?.let { ResultBadge(it, badgeTone) }
            }
        }
        if (showDivider) {
            HorizontalDivider(
                modifier = Modifier.padding(start = 44.dp),
                color = RppgVisual.RESULT_DIVIDER,
            )
        }
    }
}

@Composable
private fun ResultBadge(label: String, tone: BadgeTone) {
    val background = when (tone) {
        BadgeTone.Positive -> RppgVisual.BADGE_BACKGROUND
        BadgeTone.Caution -> RppgVisual.CAUTION_BADGE_BACKGROUND
        BadgeTone.Neutral -> RppgVisual.NEUTRAL_BADGE_BACKGROUND
    }
    val contentColor = when (tone) {
        BadgeTone.Positive -> RppgVisual.BADGE_TEXT
        BadgeTone.Caution -> RppgVisual.CAUTION_BADGE_TEXT
        BadgeTone.Neutral -> RppgVisual.NEUTRAL_BADGE_TEXT
    }
    Text(
        label,
        modifier = Modifier
            .background(background, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 3.dp),
        color = contentColor,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Medium,
    )
}

private fun RppgPhase.isResultPhase(): Boolean =
    this == RppgPhase.Completed || this == RppgPhase.LowQuality || this == RppgPhase.Error

private fun RppgMeasurementState.measurementHeadline(): String = when (phase) {
    RppgPhase.Ready -> "准备开始测量"
    RppgPhase.PreviewPreparing -> "正在准备检测…"
    RppgPhase.PreviewReady -> "准备完成"
    RppgPhase.StartPending -> "正在准备检测…"
    RppgPhase.Aligning -> "请将面部置于框内"
    RppgPhase.Collecting -> "正在采集生命体征信号"
    RppgPhase.Estimating ->
        if (result == null && respiration == null) "正在估计生命体征" else "初步结果持续更新中"
    RppgPhase.PermissionDenied -> "需要摄像头权限"
    RppgPhase.Cancelled -> "测量已取消"
    else -> "请保持稳定"
}

private fun RppgMeasurementState.measurementInstruction(): String = when (phase) {
    RppgPhase.Ready -> "原始画面仅在本机处理，不保存、不上传"
    RppgPhase.PreviewPreparing -> if (message.startsWith("准备时间较长")) {
        message
    } else {
        "请将面部置于框内并保持稳定"
    }
    RppgPhase.PreviewReady -> "点击开始测量"
    RppgPhase.StartPending -> if (message.startsWith("准备时间较长")) {
        message
    } else {
        "准备完成后将自动开始"
    }
    RppgPhase.Aligning -> "保持正脸、光线均匀和手机稳定"
    RppgPhase.Collecting -> "保持稳定；前 10 秒用于采集信号"
    RppgPhase.Estimating ->
        if (result == null && respiration == null) {
            "暂未获得可靠数值，请继续保持稳定"
        } else {
            "当前为初步估计，20 秒结果将覆盖更新"
        }
    RppgPhase.PermissionDenied -> "请允许摄像头权限后重新测量"
    RppgPhase.Cancelled -> "本次测量结果未保存"
    else -> "请改善光线后重试"
}

private fun Double.qualityLabel(): String = when {
    this >= RppgConfidencePolicy.HIGH_CONFIDENCE_THRESHOLD -> "高"
    else -> "仅供参考"
}

private fun MetricEstimate?.displayValue(): String =
    takeIf { it?.available == true }
        ?.value
        ?.takeIf(Double::isFinite)
        ?.toInt()
        ?.toString()
        ?: "--"

private fun MetricEstimate?.confidenceBadge(): String? = when (RppgConfidencePolicy.labelFor(this)) {
    RppgConfidenceLabel.HighConfidence -> "高可信"
    RppgConfidenceLabel.ReferenceOnly -> "仅供参考"
    null -> null
}

private fun MetricEstimate?.confidenceBadgeTone(): BadgeTone =
    if (RppgConfidencePolicy.labelFor(this) == RppgConfidenceLabel.ReferenceOnly) {
        BadgeTone.Caution
    } else {
        BadgeTone.Positive
    }

private fun RppgMeasurementState.resultAppearance(): ResultAppearance = when (phase) {
    RppgPhase.Completed -> ResultAppearance(
        title = "检测完成",
        icon = Icons.Filled.CheckCircle,
        color = RppgVisual.SUCCESS,
    )
    RppgPhase.LowQuality -> ResultAppearance(
        title = "信号质量不足",
        icon = Icons.Outlined.SignalCellularAlt,
        color = RppgVisual.WARNING,
    )
    else -> ResultAppearance(
        title = "检测未完成",
        icon = Icons.Outlined.ErrorOutline,
        color = RppgVisual.ERROR,
    )
}

private data class ResultAppearance(
    val title: String,
    val icon: ImageVector,
    val color: Color,
)

private data class FaceGuideGeometry(
    val width: Dp,
    val height: Dp,
    val offsetY: Dp,
)

private enum class BadgeTone {
    Positive,
    Caution,
    Neutral,
}

private val RESULT_TIME_FORMATTER =
    DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm", Locale.SIMPLIFIED_CHINESE)

private object RppgVisual {
    const val TICK_MILLIS = 100L
    const val TIMER_PROGRESS_ANIMATION_MILLIS = 120
    const val GUIDE_WIDTH_FRACTION = 0.90f
    const val GUIDE_ASPECT_RATIO = 0.78f
    const val COMPACT_GUIDE_ASPECT_RATIO = 0.82f
    const val TOP_RESERVED_FRACTION = 0.22f
    const val COMPACT_TOP_RESERVED_FRACTION = 0.20f
    const val BOTTOM_RESERVED_FRACTION = 0.22f
    const val GUIDE_VERTICAL_BIAS = 0.36f
    const val OUTSIDE_FOCUS_ALPHA = 0.24f
    const val FOCUS_FEATHER_STEPS = 8

    val COMPACT_HEIGHT_THRESHOLD: Dp = 720.dp
    val GUIDE_STROKE_WIDTH: Dp = 1.8.dp
    val FOCUS_FEATHER_WIDTH: Dp = 12.dp
    val SCREEN_HORIZONTAL_PADDING: Dp = 18.dp
    val RESULT_HORIZONTAL_PADDING: Dp = 24.dp
    val TOP_PADDING: Dp = 8.dp
    val BOTTOM_PADDING: Dp = 22.dp
    val NAVIGATION_HEIGHT: Dp = 54.dp
    val NAVIGATION_CONTROL_SIZE: Dp = 44.dp
    val CONTROL_RADIUS: Dp = 16.dp
    val INFO_RADIUS: Dp = 18.dp
    val PRIMARY_BUTTON_HEIGHT: Dp = 52.dp
    val PRIMARY_BUTTON_RADIUS: Dp = 18.dp
    val PROGRESS_HEIGHT: Dp = 3.dp
    val RESULT_ROW_MIN_HEIGHT: Dp = 76.dp
    val RESULT_BOTTOM_SPACING: Dp = 30.dp

    val PREVIEW_FALLBACK = Color(0xFF111716)
    val RESULT_BACKGROUND = Color(0xFF070A0B)
    val TOP_GRADIENT_STRONG = Color(0xE61A2524)
    val TOP_GRADIENT_MID = Color(0xA61A2524)
    val BOTTOM_GRADIENT_MID = Color(0xA6000000)
    val BOTTOM_GRADIENT_STRONG = Color(0xEB050707)
    val INFO_SURFACE = Color(0x4D101716)
    val CONTROL_SURFACE = Color(0x52232928)
    val GUIDE_COLOR = Color.White.copy(alpha = 0.82f)
    val OUTSIDE_FOCUS_BASE = Color(0xFF101716)
    val OUTSIDE_FOCUS_MASK = OUTSIDE_FOCUS_BASE.copy(alpha = OUTSIDE_FOCUS_ALPHA)
    val ACCENT = Color(0xFF2CBCAF)
    val SUCCESS = Color(0xFF3DDC84)
    val WARNING = Color(0xFFFFB74D)
    val ERROR = Color(0xFFFF6B6B)
    val HEART_COLOR = Color(0xFFFF4D63)
    val RESPIRATION_COLOR = Color(0xFF42D994)
    val OXYGEN_COLOR = Color(0xFF3B9EFF)
    val STRESS_COLOR = Color(0xFFFF993D)
    val SIGNAL_COLOR = Color(0xFFD44CE8)
    val RMSSD_COLOR = Color(0xFF55C8E8)
    val RESULT_SECONDARY_TEXT = Color(0xFF969B9E)
    val RESULT_SECTION_TEXT = Color(0xFF858B8E)
    val RESULT_DIVIDER = Color(0xFF242829)
    val BADGE_BACKGROUND = Color(0xFF174D35)
    val BADGE_TEXT = Color(0xFF69E6A4)
    val CAUTION_BADGE_BACKGROUND = Color(0xFF533A16)
    val CAUTION_BADGE_TEXT = Color(0xFFFFC66D)
    val NEUTRAL_BADGE_BACKGROUND = Color(0xFF293033)
    val NEUTRAL_BADGE_TEXT = Color(0xFFBEC5C8)
}
