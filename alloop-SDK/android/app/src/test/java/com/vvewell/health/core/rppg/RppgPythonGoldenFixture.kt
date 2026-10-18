package com.vvewell.health.core.rppg

/**
 * Extensible CSV contract for future Python parity fixtures.
 *
 * Metadata lines use `# key=value`. Columns may include:
 * timestamp,bvp,resampled,filtered,imf_0,hilbert_real,hilbert_imag,phase,instantaneous_hz.
 * This stage intentionally ships no fabricated Python golden values.
 */
internal data class RppgPythonGoldenFixture(
    val metadata: Map<String, String>,
    val columns: List<String>,
    val rows: List<Map<String, Double>>,
) {
    fun timedSamples(): List<TimedRppgSample> = rows.map { row ->
        TimedRppgSample(
            timestampSeconds = requireNotNull(row["timestamp"]),
            value = requireNotNull(row["bvp"]),
        )
    }
}

internal object RppgPythonGoldenFixtureParser {
    fun parse(text: String): RppgPythonGoldenFixture {
        val lines = text.lineSequence().map(String::trim).filter(String::isNotEmpty).toList()
        val metadata = lines.filter { it.startsWith("#") }.associate { line ->
            val parts = line.removePrefix("#").trim().split("=", limit = 2)
            require(parts.size == 2) { "Golden metadata must use '# key=value'" }
            parts[0].trim() to parts[1].trim()
        }
        val dataLines = lines.filterNot { it.startsWith("#") }
        require(dataLines.size >= 2) { "Golden fixture requires a header and data" }
        val columns = dataLines.first().split(",").map(String::trim)
        require(columns.containsAll(listOf("timestamp", "bvp"))) {
            "Golden fixture requires timestamp and bvp columns"
        }
        val rows = dataLines.drop(1).map { line ->
            val values = line.split(",").map(String::trim)
            require(values.size == columns.size) { "Golden row width does not match header" }
            columns.zip(values).associate { (column, value) -> column to value.toDouble() }
        }
        return RppgPythonGoldenFixture(metadata, columns, rows)
    }
}
