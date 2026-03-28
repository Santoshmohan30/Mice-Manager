package com.sonny03.micemanager

import android.content.Context
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val repository = MobileRepository()
        val viewModel = ViewModelProvider(
            this,
            MobileViewModelFactory(repository)
        )[MobileViewModel::class.java]

        setContent {
            MaterialTheme {
                MobileApp(viewModel)
            }
        }
    }
}

enum class MobileScreen(val label: String) {
    Dashboard("Dashboard"),
    Mice("Mice"),
    Scan("Scan"),
    Editor("Editor"),
    Analytics("Analytics"),
}

enum class ScanMode(val label: String) {
    Fill("Fill Form"),
    Archive("Archive"),
}

data class MouseSummary(
    val id: Int,
    val strain: String,
    val groupType: String,
    val cage: String,
    val rackLocation: String,
    val genotype: String,
    val gender: String,
    val dob: String,
    val training: Boolean,
    val project: String,
    val ownerPi: String,
    val protocolNumber: String,
    val animalCount: String,
    val receivedDate: String,
    val vendor: String,
    val age: String,
    val weight: String,
    val species: String,
    val room: String,
    val requisitionNumber: String,
    val costCenter: String,
    val notes: String,
    val isActive: Boolean,
)

data class DashboardSummary(
    val totalMice: Int,
    val totalStrains: Int,
    val trainingMice: Int,
    val activeBreedings: Int,
)

data class ChartPoint(val label: String, val value: Int)

data class AnalyticsSummary(
    val trueStrains: List<ChartPoint>,
    val procedureCohorts: List<ChartPoint>,
    val racks: List<ChartPoint>,
)

data class MouseEditorState(
    val id: Int? = null,
    val strain: String = "",
    val groupType: String = "genetic_strain",
    val gender: String = "MALE",
    val genotype: String = "",
    val dob: String = "",
    val cage: String = "",
    val rackLocation: String = "",
    val project: String = "",
    val ownerPi: String = "",
    val protocolNumber: String = "",
    val animalCount: String = "",
    val receivedDate: String = "",
    val vendor: String = "",
    val age: String = "",
    val weight: String = "",
    val species: String = "",
    val room: String = "",
    val requisitionNumber: String = "",
    val costCenter: String = "",
    val notes: String = "",
    val training: Boolean = false,
)

data class CageCardParseResult(
    val rawText: String,
    val confidence: Double,
    val editor: MouseEditorState,
    val warnings: List<String>,
    val matches: List<MouseSummary>,
)

class MobileRepository {
    var baseUrl = "http://192.168.68.58:8000"

    suspend fun login(username: String, password: String): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val payload = JSONObject()
                .put("username", username)
                .put("password", password)

            val connection = jsonConnection("$baseUrl/api/login", "POST")
            connection.doOutput = true
            OutputStreamWriter(connection.outputStream).use { it.write(payload.toString()) }

            val body = connection.readBody()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException(JSONObject(body).optString("error", "Login failed"))
            }
            JSONObject(body).getString("token")
        }
    }

    suspend fun dashboard(token: String): Result<DashboardSummary> = withContext(Dispatchers.IO) {
        runCatching {
            val connection = authedConnection("$baseUrl/api/dashboard", token)
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException("Failed to load dashboard")
            val stats = JSONObject(body).getJSONObject("stats")
            DashboardSummary(
                totalMice = stats.getInt("total_mice"),
                totalStrains = stats.getInt("strains"),
                trainingMice = stats.getInt("training_mice"),
                activeBreedings = stats.getInt("active_breedings"),
            )
        }
    }

    suspend fun mice(token: String): Result<List<MouseSummary>> = withContext(Dispatchers.IO) {
        runCatching {
            val connection = authedConnection("$baseUrl/api/mice", token)
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException("Failed to load mice")
            val items = JSONArray(body)
            buildList {
                for (index in 0 until items.length()) {
                    add(parseMouse(items.getJSONObject(index)))
                }
            }
        }
    }

    suspend fun analytics(token: String): Result<AnalyticsSummary> = withContext(Dispatchers.IO) {
        runCatching {
            val connection = authedConnection("$baseUrl/api/analytics", token)
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException("Failed to load analytics")
            val json = JSONObject(body)
            AnalyticsSummary(
                trueStrains = parseChartObject(json.getJSONObject("true_strains")),
                procedureCohorts = parseChartObject(json.getJSONObject("procedure_cohorts")),
                racks = parseChartObject(json.getJSONObject("racks")),
            )
        }
    }

    suspend fun createMouse(token: String, editor: MouseEditorState): Result<MouseSummary> = withContext(Dispatchers.IO) {
        runCatching {
            val connection = jsonConnection("$baseUrl/api/mice", "POST")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.doOutput = true
            OutputStreamWriter(connection.outputStream).use { it.write(editor.toJson().toString()) }
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException(JSONObject(body).optString("error", "Failed to create mouse"))
            parseMouse(JSONObject(body))
        }
    }

    suspend fun updateMouse(token: String, editor: MouseEditorState): Result<MouseSummary> = withContext(Dispatchers.IO) {
        runCatching {
            val mouseId = editor.id ?: throw IllegalStateException("Mouse id is required")
            val connection = jsonConnection("$baseUrl/api/mice/$mouseId", "PUT")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.doOutput = true
            OutputStreamWriter(connection.outputStream).use { it.write(editor.toJson().toString()) }
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException(JSONObject(body).optString("error", "Failed to update mouse"))
            parseMouse(JSONObject(body))
        }
    }

    suspend fun archiveMouse(token: String, mouseId: Int): Result<Unit> = withContext(Dispatchers.IO) {
        runCatching {
            val connection = authedConnection("$baseUrl/api/mice/$mouseId", token, "DELETE")
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException(JSONObject(body).optString("error", "Failed to archive mouse"))
        }
    }

    suspend fun parseCageCard(token: String, rawText: String): Result<CageCardParseResult> = withContext(Dispatchers.IO) {
        runCatching {
            val payload = JSONObject().put("text", rawText)
            val connection = jsonConnection("$baseUrl/api/cage-card/parse", "POST")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.doOutput = true
            OutputStreamWriter(connection.outputStream).use { it.write(payload.toString()) }
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) throw IllegalStateException(JSONObject(body).optString("error", "Failed to parse cage card"))
            val json = JSONObject(body)
            CageCardParseResult(
                rawText = json.optString("raw_text"),
                confidence = json.optDouble("confidence", 0.0),
                editor = parseEditor(json.getJSONObject("editor")),
                warnings = json.getJSONArray("warnings").toStringList(),
                matches = json.getJSONArray("matches").toMouseList(),
            )
        }
    }

    suspend fun scanCageCardImage(token: String, context: Context, imageUri: Uri): Result<CageCardParseResult> = withContext(Dispatchers.IO) {
        runCatching {
            val boundary = "MICE_MANAGER_${System.currentTimeMillis()}"
            val connection = URL("$baseUrl/api/cage-card/scan-image").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.doOutput = true
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")

            val fileName = context.contentResolver.getType(imageUri)?.substringAfterLast("/")?.let { "scan.$it" } ?: "scan.jpg"
            connection.outputStream.use { output ->
                output.write("--$boundary\r\n".toByteArray())
                output.write("Content-Disposition: form-data; name=\"image\"; filename=\"$fileName\"\r\n".toByteArray())
                output.write("Content-Type: ${context.contentResolver.getType(imageUri) ?: "image/jpeg"}\r\n\r\n".toByteArray())
                context.contentResolver.openInputStream(imageUri)?.use { input -> input.copyTo(output) }
                    ?: throw IllegalStateException("Unable to read the selected image.")
                output.write("\r\n--$boundary--\r\n".toByteArray())
            }

            val body = connection.readBody()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException(JSONObject(body).optString("error", "Failed to scan cage card image"))
            }
            val json = JSONObject(body)
            CageCardParseResult(
                rawText = json.optString("raw_text"),
                confidence = json.optDouble("confidence", 0.0),
                editor = parseEditor(json.getJSONObject("editor")),
                warnings = json.getJSONArray("warnings").toStringList(),
                matches = json.getJSONArray("matches").toMouseList(),
            )
        }
    }

    private fun parseMouse(item: JSONObject): MouseSummary {
        return MouseSummary(
            id = item.getInt("id"),
            strain = item.getString("strain"),
            groupType = item.optString("group_type", "genetic_strain"),
            cage = item.optString("cage"),
            rackLocation = item.optString("rack_location"),
            genotype = item.optString("genotype"),
            gender = item.optString("gender"),
            dob = item.optString("dob"),
            training = item.optBoolean("training"),
            project = item.optString("project"),
            ownerPi = item.optString("owner_pi"),
            protocolNumber = item.optString("protocol_number"),
            animalCount = item.optString("animal_count"),
            receivedDate = item.optString("received_date"),
            vendor = item.optString("vendor"),
            age = item.optString("age"),
            weight = item.optString("weight"),
            species = item.optString("species"),
            room = item.optString("room"),
            requisitionNumber = item.optString("requisition_number"),
            costCenter = item.optString("cost_center"),
            notes = item.optString("notes"),
            isActive = item.optBoolean("is_active", true),
        )
    }

    private fun parseEditor(item: JSONObject): MouseEditorState {
        return MouseEditorState(
            strain = item.optString("strain"),
            groupType = item.optString("group_type", "genetic_strain"),
            gender = item.optString("gender", "MALE"),
            genotype = item.optString("genotype"),
            dob = item.optString("dob"),
            cage = item.optString("cage"),
            rackLocation = item.optString("rack_location"),
            project = item.optString("project"),
            ownerPi = item.optString("owner_pi"),
            protocolNumber = item.optString("protocol_number"),
            animalCount = item.optString("animal_count"),
            receivedDate = item.optString("received_date"),
            vendor = item.optString("vendor"),
            age = item.optString("age"),
            weight = item.optString("weight"),
            species = item.optString("species"),
            room = item.optString("room"),
            requisitionNumber = item.optString("requisition_number"),
            costCenter = item.optString("cost_center"),
            notes = item.optString("notes"),
            training = item.optBoolean("training", false),
        )
    }

    private fun parseChartObject(json: JSONObject): List<ChartPoint> {
        val keys = json.keys().asSequence().toList().sorted()
        return keys.map { key -> ChartPoint(key, json.optInt(key, 0)) }.sortedByDescending { it.value }
    }

    private fun jsonConnection(url: String, method: String): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.setRequestProperty("Content-Type", "application/json")
        return connection
    }

    private fun authedConnection(url: String, token: String, method: String = "GET"): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.requestMethod = method
        connection.setRequestProperty("Authorization", "Bearer $token")
        return connection
    }

    private fun HttpURLConnection.readBody(): String {
        val stream = if (responseCode in 200..299) inputStream else errorStream
        return BufferedReader(stream.reader()).use { it.readText() }
    }

    private fun JSONArray.toStringList(): List<String> {
        return buildList {
            for (index in 0 until length()) {
                add(optString(index))
            }
        }
    }

    private fun JSONArray.toMouseList(): List<MouseSummary> {
        return buildList {
            for (index in 0 until length()) {
                add(parseMouse(getJSONObject(index)))
            }
        }
    }
}

private fun MouseEditorState.toJson(): JSONObject {
    return JSONObject()
        .put("strain", strain)
        .put("group_type", groupType)
        .put("gender", gender)
        .put("genotype", genotype)
        .put("dob", dob)
        .put("cage", cage)
        .put("rack_location", rackLocation)
        .put("project", project)
        .put("owner_pi", ownerPi)
        .put("protocol_number", protocolNumber)
        .put("animal_count", animalCount)
        .put("received_date", receivedDate)
        .put("vendor", vendor)
        .put("age", age)
        .put("weight", weight)
        .put("species", species)
        .put("room", room)
        .put("requisition_number", requisitionNumber)
        .put("cost_center", costCenter)
        .put("notes", notes)
        .put("training", training)
}

class MobileViewModel(private val repository: MobileRepository) : ViewModel() {
    var username by mutableStateOf("")
    var password by mutableStateOf("")
    var serverUrl by mutableStateOf(repository.baseUrl)
    var token by mutableStateOf<String?>(null)
    var currentScreen by mutableStateOf(MobileScreen.Dashboard)
    var summary by mutableStateOf<DashboardSummary?>(null)
    var analytics by mutableStateOf<AnalyticsSummary?>(null)
    var mice by mutableStateOf(emptyList<MouseSummary>())
    var editor by mutableStateOf(MouseEditorState())
    var scanMode by mutableStateOf(ScanMode.Fill)
    var scanResult by mutableStateOf<CageCardParseResult?>(null)
    var statusMessage by mutableStateOf<String?>(null)
    var isLoading by mutableStateOf(false)

    fun signIn() {
        statusMessage = null
        isLoading = true
        repository.baseUrl = serverUrl.trim().removeSuffix("/")
        viewModelScope.launch {
            repository.login(username, password)
                .onSuccess { signedToken ->
                    token = signedToken
                    refreshAll()
                }
                .onFailure {
                    isLoading = false
                    statusMessage = it.message
                }
        }
    }

    fun refreshAll() {
        val authToken = token ?: return
        isLoading = true
        viewModelScope.launch {
            val dashboardResult = repository.dashboard(authToken)
            val miceResult = repository.mice(authToken)
            val analyticsResult = repository.analytics(authToken)

            dashboardResult.onSuccess { summary = it }
            miceResult.onSuccess { mice = it }
            analyticsResult.onSuccess { analytics = it }

            statusMessage =
                dashboardResult.exceptionOrNull()?.message
                    ?: miceResult.exceptionOrNull()?.message
                    ?: analyticsResult.exceptionOrNull()?.message
            isLoading = false
        }
    }

    fun beginCreate() {
        editor = MouseEditorState()
        currentScreen = MobileScreen.Editor
    }

    fun beginEdit(mouse: MouseSummary) {
        editor = MouseEditorState(
            id = mouse.id,
            strain = mouse.strain,
            groupType = mouse.groupType,
            gender = mouse.gender,
            genotype = mouse.genotype,
            dob = mouse.dob,
            cage = mouse.cage,
            rackLocation = mouse.rackLocation,
            project = mouse.project,
            ownerPi = mouse.ownerPi,
            protocolNumber = mouse.protocolNumber,
            animalCount = mouse.animalCount,
            receivedDate = mouse.receivedDate,
            vendor = mouse.vendor,
            age = mouse.age,
            weight = mouse.weight,
            species = mouse.species,
            room = mouse.room,
            requisitionNumber = mouse.requisitionNumber,
            costCenter = mouse.costCenter,
            notes = mouse.notes,
            training = mouse.training,
        )
        currentScreen = MobileScreen.Editor
    }

    fun saveEditor() {
        val authToken = token ?: return
        statusMessage = null
        isLoading = true
        viewModelScope.launch {
            val result = if (editor.id == null) repository.createMouse(authToken, editor) else repository.updateMouse(authToken, editor)
            result.onSuccess {
                statusMessage = if (editor.id == null) "Mouse created" else "Mouse updated"
                currentScreen = MobileScreen.Mice
                refreshAll()
            }.onFailure {
                isLoading = false
                statusMessage = it.message
            }
        }
    }

    fun parseScanText(text: String) {
        val authToken = token ?: return
        statusMessage = null
        isLoading = true
        viewModelScope.launch {
            repository.parseCageCard(authToken, text)
                .onSuccess {
                    scanResult = it
                    if (scanMode == ScanMode.Fill) {
                        val exactMatch = it.matches.firstOrNull()
                        editor = if (exactMatch != null) mergeScanEditorWithMatch(it.editor, exactMatch) else it.editor
                    }
                    currentScreen = MobileScreen.Scan
                    isLoading = false
                }
                .onFailure {
                    isLoading = false
                    statusMessage = it.message
                }
        }
    }

    fun useScanInEditor() {
        currentScreen = MobileScreen.Editor
    }

    private fun mergeScanEditorWithMatch(scanEditor: MouseEditorState, exactMatch: MouseSummary): MouseEditorState {
        return MouseEditorState(
            id = exactMatch.id,
            strain = if (scanEditor.strain.isNotBlank()) scanEditor.strain else exactMatch.strain,
            groupType = if (scanEditor.groupType.isNotBlank()) scanEditor.groupType else exactMatch.groupType,
            gender = if (scanEditor.gender.isNotBlank()) scanEditor.gender else exactMatch.gender,
            genotype = if (scanEditor.genotype.isNotBlank()) scanEditor.genotype else exactMatch.genotype,
            dob = if (scanEditor.dob.isNotBlank()) scanEditor.dob else exactMatch.dob,
            cage = if (scanEditor.cage.isNotBlank()) scanEditor.cage else exactMatch.cage,
            rackLocation = if (scanEditor.rackLocation.isNotBlank()) scanEditor.rackLocation else exactMatch.rackLocation,
            project = if (scanEditor.project.isNotBlank()) scanEditor.project else exactMatch.project,
            ownerPi = if (scanEditor.ownerPi.isNotBlank()) scanEditor.ownerPi else exactMatch.ownerPi,
            protocolNumber = if (scanEditor.protocolNumber.isNotBlank()) scanEditor.protocolNumber else exactMatch.protocolNumber,
            animalCount = if (scanEditor.animalCount.isNotBlank()) scanEditor.animalCount else exactMatch.animalCount,
            receivedDate = if (scanEditor.receivedDate.isNotBlank()) scanEditor.receivedDate else exactMatch.receivedDate,
            vendor = if (scanEditor.vendor.isNotBlank()) scanEditor.vendor else exactMatch.vendor,
            age = if (scanEditor.age.isNotBlank()) scanEditor.age else exactMatch.age,
            weight = if (scanEditor.weight.isNotBlank()) scanEditor.weight else exactMatch.weight,
            species = if (scanEditor.species.isNotBlank()) scanEditor.species else exactMatch.species,
            room = if (scanEditor.room.isNotBlank()) scanEditor.room else exactMatch.room,
            requisitionNumber = if (scanEditor.requisitionNumber.isNotBlank()) scanEditor.requisitionNumber else exactMatch.requisitionNumber,
            costCenter = if (scanEditor.costCenter.isNotBlank()) scanEditor.costCenter else exactMatch.costCenter,
            notes = listOf(exactMatch.notes, scanEditor.notes).filter { value -> value.isNotBlank() }.joinToString(" | "),
            training = scanEditor.training || exactMatch.training,
        )
    }

    fun scanImage(context: Context, imageUri: Uri) {
        val authToken = token ?: return
        statusMessage = null
        isLoading = true
        viewModelScope.launch {
            repository.scanCageCardImage(authToken, context, imageUri)
                .onSuccess {
                    scanResult = it
                    if (scanMode == ScanMode.Fill) {
                        val exactMatch = it.matches.firstOrNull()
                        editor = if (exactMatch != null) mergeScanEditorWithMatch(it.editor, exactMatch) else it.editor
                    }
                    currentScreen = MobileScreen.Scan
                    isLoading = false
                }
                .onFailure {
                    isLoading = false
                    statusMessage = it.message
                }
        }
    }

    fun archiveMouse(mouseId: Int) {
        val authToken = token ?: return
        isLoading = true
        viewModelScope.launch {
            repository.archiveMouse(authToken, mouseId)
                .onSuccess {
                    statusMessage = "Mouse archived"
                    scanResult = scanResult?.copy(matches = scanResult?.matches?.filterNot { it.id == mouseId } ?: emptyList())
                    refreshAll()
                }
                .onFailure {
                    isLoading = false
                    statusMessage = it.message
                }
        }
    }
}

class MobileViewModelFactory(
    private val repository: MobileRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        @Suppress("UNCHECKED_CAST")
        return MobileViewModel(repository) as T
    }
}

@Composable
fun MobileApp(viewModel: MobileViewModel) {
    if (viewModel.token == null) {
        LoginScreen(viewModel)
    } else {
        AuthenticatedApp(viewModel)
    }
}

@Composable
fun LoginScreen(viewModel: MobileViewModel) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text("Mice Manager", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(8.dp))
        Text("Use your laptop Wi-Fi URL for a real phone connection.", style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.height(20.dp))
        OutlinedTextField(
            value = viewModel.serverUrl,
            onValueChange = { viewModel.serverUrl = it },
            label = { Text("Server URL") },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(12.dp))
        OutlinedTextField(
            value = viewModel.username,
            onValueChange = { viewModel.username = it },
            label = { Text("Username") },
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(12.dp))
        OutlinedTextField(
            value = viewModel.password,
            onValueChange = { viewModel.password = it },
            label = { Text("Password") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(modifier = Modifier.height(16.dp))
        Button(onClick = { viewModel.signIn() }, modifier = Modifier.fillMaxWidth()) {
            if (viewModel.isLoading) CircularProgressIndicator() else Text("Sign In")
        }
        viewModel.statusMessage?.let {
            Spacer(modifier = Modifier.height(12.dp))
            Text(it, color = MaterialTheme.colorScheme.error)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthenticatedApp(viewModel: MobileViewModel) {
    val snackbarHostState = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(viewModel.statusMessage) {
        val message = viewModel.statusMessage ?: return@LaunchedEffect
        scope.launch { snackbarHostState.showSnackbar(message) }
        viewModel.statusMessage = null
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Mice Manager Mobile") },
                actions = {
                    TextButton(onClick = { viewModel.refreshAll() }) { Text("Refresh") }
                    TextButton(onClick = {
                        viewModel.scanMode = ScanMode.Fill
                        viewModel.currentScreen = MobileScreen.Scan
                    }) { Text("Scan Card") }
                    TextButton(onClick = { viewModel.beginCreate() }) { Text("New Mouse") }
                }
            )
        },
        bottomBar = {
            NavigationBar {
                MobileScreen.entries.forEach { screen ->
                    NavigationBarItem(
                        selected = viewModel.currentScreen == screen,
                        onClick = { viewModel.currentScreen = screen },
                        icon = {},
                        label = { Text(screen.label) }
                    )
                }
            }
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) }
    ) { padding ->
        when (viewModel.currentScreen) {
            MobileScreen.Dashboard -> DashboardScreen(viewModel, Modifier.padding(padding))
            MobileScreen.Mice -> MiceScreen(viewModel, Modifier.padding(padding))
            MobileScreen.Scan -> ScanScreen(viewModel, Modifier.padding(padding))
            MobileScreen.Editor -> EditorScreen(viewModel, Modifier.padding(padding))
            MobileScreen.Analytics -> AnalyticsScreen(viewModel, Modifier.padding(padding))
        }
    }
}

@Composable
fun DashboardScreen(viewModel: MobileViewModel, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            viewModel.summary?.let { summary ->
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    SummaryCard("Mice", summary.totalMice.toString(), Modifier.weight(1f))
                    SummaryCard("Strains", summary.totalStrains.toString(), Modifier.weight(1f))
                    SummaryCard("Training", summary.trainingMice.toString(), Modifier.weight(1f))
                    SummaryCard("Breeding", summary.activeBreedings.toString(), Modifier.weight(1f))
                }
            }
        }
        item {
            Card {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Mobile Workflow", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("Use Scan to read a cage card photo, review the extracted values, then save or archive faster.")
                }
            }
        }
    }
}

@Composable
fun MiceScreen(viewModel: MobileViewModel, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(viewModel.mice) { mouse ->
            Card {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("#${mouse.id} · ${mouse.strain}", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(6.dp))
                    Text("${mouse.groupType} · ${mouse.gender} · Cage ${mouse.cage}")
                    Text("Rack: ${mouse.rackLocation.ifBlank { "Unassigned" }}")
                    Text("Genotype: ${mouse.genotype}")
                    Text("DOB: ${mouse.dob}")
                    if (mouse.ownerPi.isNotBlank()) Text("Owner / PI: ${mouse.ownerPi}")
                    if (mouse.protocolNumber.isNotBlank()) Text("Protocol: ${mouse.protocolNumber}")
                    if (mouse.animalCount.isNotBlank()) Text("Animals: ${mouse.animalCount}")
                    Text("Training: ${if (mouse.training) "Yes" else "No"}")
                    if (mouse.project.isNotBlank()) Text("Project: ${mouse.project}")
                    if (mouse.notes.isNotBlank()) Text("Notes: ${mouse.notes}")
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(onClick = { viewModel.beginEdit(mouse) }, modifier = Modifier.weight(1f)) {
                            Text("Edit")
                        }
                        Button(
                            onClick = { viewModel.archiveMouse(mouse.id) },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Archive")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun ScanScreen(viewModel: MobileViewModel, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var pendingCameraUri by remember { mutableStateOf<Uri?>(null) }

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicture()
    ) { success: Boolean ->
        val imageUri = pendingCameraUri
        if (!success || imageUri == null) {
            viewModel.statusMessage = "No image was captured."
            return@rememberLauncherForActivityResult
        }
        viewModel.scanImage(context, imageUri)
    }

    val galleryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri == null) {
            viewModel.statusMessage = "No image was selected."
            return@rememberLauncherForActivityResult
        }
        viewModel.scanImage(context, uri)
    }

    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Card {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("Scan Cage Card", style = MaterialTheme.typography.titleMedium)
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = { viewModel.scanMode = ScanMode.Fill },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (viewModel.scanMode == ScanMode.Fill) "Fill Form Active" else "Fill Form")
                        }
                        Button(
                            onClick = { viewModel.scanMode = ScanMode.Archive },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (viewModel.scanMode == ScanMode.Archive) "Archive Active" else "Archive")
                        }
                    }
                    Spacer(modifier = Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = {
                                val uri = createTempImageUri(context)
                                pendingCameraUri = uri
                                cameraLauncher.launch(uri)
                            },
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("Take Photo")
                        }
                        Button(onClick = { galleryLauncher.launch("image/*") }, modifier = Modifier.weight(1f)) {
                            Text("Pick Image")
                        }
                    }
                    if (viewModel.isLoading) {
                        Spacer(modifier = Modifier.height(12.dp))
                        CircularProgressIndicator()
                    }
                }
            }
        }

        item {
            viewModel.scanResult?.let { result ->
                Card {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("Extracted Card Data", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("Confidence: ${(result.confidence * 100).toInt()}%")
                        Text("Strain: ${result.editor.strain.ifBlank { "Not found" }}")
                        Text("Group: ${result.editor.groupType}")
                        Text("Gender: ${result.editor.gender.ifBlank { "Not found" }}")
                        Text("Genotype: ${result.editor.genotype.ifBlank { "Not found" }}")
                        Text("DOB: ${result.editor.dob.ifBlank { "Not found" }}")
                        Text("Cage: ${result.editor.cage.ifBlank { "Not found" }}")
                        Text("Rack: ${result.editor.rackLocation.ifBlank { "Not found" }}")
                        Text("Owner / PI: ${result.editor.ownerPi.ifBlank { "Not found" }}")
                        Text("Protocol: ${result.editor.protocolNumber.ifBlank { "Not found" }}")
                        Text("Animals: ${result.editor.animalCount.ifBlank { "Not found" }}")
                        if (result.editor.receivedDate.isNotBlank()) Text("Received: ${result.editor.receivedDate}")
                        if (result.editor.vendor.isNotBlank()) Text("Vendor: ${result.editor.vendor}")
                        if (result.editor.age.isNotBlank()) Text("Age: ${result.editor.age}")
                        if (result.editor.weight.isNotBlank()) Text("Weight: ${result.editor.weight}")
                        if (result.editor.species.isNotBlank()) Text("Species: ${result.editor.species}")
                        if (result.editor.room.isNotBlank()) Text("Room: ${result.editor.room}")
                        if (result.editor.requisitionNumber.isNotBlank()) Text("Requisition: ${result.editor.requisitionNumber}")
                        if (result.editor.costCenter.isNotBlank()) Text("Cost Center: ${result.editor.costCenter}")
                        if (result.editor.project.isNotBlank()) Text("Project: ${result.editor.project}")
                        if (result.warnings.isNotEmpty()) {
                            Spacer(modifier = Modifier.height(8.dp))
                            result.warnings.forEach { warning ->
                                Text(warning, color = MaterialTheme.colorScheme.error)
                            }
                        }
                        Spacer(modifier = Modifier.height(10.dp))
                        if (viewModel.scanMode == ScanMode.Fill) {
                            Button(onClick = { viewModel.useScanInEditor() }, modifier = Modifier.fillMaxWidth()) {
                                Text("Review In Editor")
                            }
                        }
                    }
                }
            }
        }

        item {
            if (!viewModel.scanResult?.rawText.isNullOrBlank()) {
                Card {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("OCR Text", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(viewModel.scanResult?.rawText ?: "")
                    }
                }
            }
        }

        item {
            val matches = viewModel.scanResult?.matches ?: emptyList()
            if (matches.isNotEmpty()) {
                Text("Matching Records", style = MaterialTheme.typography.titleMedium)
            }
        }

        items(viewModel.scanResult?.matches ?: emptyList()) { mouse ->
            Card {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text("#${mouse.id} · ${mouse.strain}", style = MaterialTheme.typography.titleMedium)
                    Text("Cage ${mouse.cage} · ${mouse.gender} · ${mouse.genotype}")
                    Text("Rack: ${mouse.rackLocation.ifBlank { "Unassigned" }}")
                    if (mouse.ownerPi.isNotBlank()) Text("Owner / PI: ${mouse.ownerPi}")
                    if (mouse.protocolNumber.isNotBlank()) Text("Protocol: ${mouse.protocolNumber}")
                    Spacer(modifier = Modifier.height(10.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(onClick = { viewModel.beginEdit(mouse) }, modifier = Modifier.weight(1f)) {
                            Text("Open")
                        }
                        if (viewModel.scanMode == ScanMode.Archive) {
                            Button(onClick = { viewModel.archiveMouse(mouse.id) }, modifier = Modifier.weight(1f)) {
                                Text("Archive")
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun EditorScreen(viewModel: MobileViewModel, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            Card {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        if (viewModel.editor.id == null) "Create Mouse" else "Edit Mouse #${viewModel.editor.id}",
                        style = MaterialTheme.typography.titleMedium
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    EditorField("Strain", viewModel.editor.strain) { viewModel.editor = viewModel.editor.copy(strain = it) }
                    EditorField("Group Type", viewModel.editor.groupType) { viewModel.editor = viewModel.editor.copy(groupType = it) }
                    EditorField("Gender", viewModel.editor.gender) { viewModel.editor = viewModel.editor.copy(gender = it.uppercase()) }
                    EditorField("Genotype", viewModel.editor.genotype) { viewModel.editor = viewModel.editor.copy(genotype = it) }
                    EditorField("DOB (YYYY-MM-DD)", viewModel.editor.dob) { viewModel.editor = viewModel.editor.copy(dob = it) }
                    EditorField("Cage", viewModel.editor.cage) { viewModel.editor = viewModel.editor.copy(cage = it) }
                    EditorField("Rack Location", viewModel.editor.rackLocation) { viewModel.editor = viewModel.editor.copy(rackLocation = it) }
                    EditorField("Project", viewModel.editor.project) { viewModel.editor = viewModel.editor.copy(project = it) }
                    EditorField("Owner / PI", viewModel.editor.ownerPi) { viewModel.editor = viewModel.editor.copy(ownerPi = it) }
                    EditorField("Protocol Number", viewModel.editor.protocolNumber) { viewModel.editor = viewModel.editor.copy(protocolNumber = it) }
                    EditorField("Number of Animals", viewModel.editor.animalCount) { viewModel.editor = viewModel.editor.copy(animalCount = it) }
                    EditorField("Received Date (YYYY-MM-DD)", viewModel.editor.receivedDate) { viewModel.editor = viewModel.editor.copy(receivedDate = it) }
                    EditorField("Vendor", viewModel.editor.vendor) { viewModel.editor = viewModel.editor.copy(vendor = it) }
                    EditorField("Age", viewModel.editor.age) { viewModel.editor = viewModel.editor.copy(age = it) }
                    EditorField("Weight", viewModel.editor.weight) { viewModel.editor = viewModel.editor.copy(weight = it) }
                    EditorField("Species", viewModel.editor.species) { viewModel.editor = viewModel.editor.copy(species = it) }
                    EditorField("Room", viewModel.editor.room) { viewModel.editor = viewModel.editor.copy(room = it) }
                    EditorField("Requisition Number", viewModel.editor.requisitionNumber) { viewModel.editor = viewModel.editor.copy(requisitionNumber = it) }
                    EditorField("Cost Center", viewModel.editor.costCenter) { viewModel.editor = viewModel.editor.copy(costCenter = it) }
                    EditorField("Notes", viewModel.editor.notes) { viewModel.editor = viewModel.editor.copy(notes = it) }
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(onClick = { viewModel.editor = viewModel.editor.copy(training = !viewModel.editor.training) }) {
                            Text(if (viewModel.editor.training) "Training: Yes" else "Training: No")
                        }
                        Button(onClick = { viewModel.saveEditor() }) {
                            Text(if (viewModel.editor.id == null) "Create" else "Save")
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun AnalyticsScreen(viewModel: MobileViewModel, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            viewModel.analytics?.let { analytics ->
                ChartCard("True Strains", analytics.trueStrains)
                Spacer(modifier = Modifier.height(12.dp))
                ChartCard("Procedure Cohorts", analytics.procedureCohorts)
                Spacer(modifier = Modifier.height(12.dp))
                ChartCard("Rack Locations", analytics.racks)
            }
        }
    }
}

@Composable
fun EditorField(label: String, value: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = onChange,
        label = { Text(label) },
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 10.dp)
    )
}

@Composable
fun ChartCard(title: String, points: List<ChartPoint>) {
    Card {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(10.dp))
            points.forEach { point ->
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(point.label)
                    Text(point.value.toString())
                }
                Spacer(modifier = Modifier.height(6.dp))
            }
            if (points.isEmpty()) {
                Text("No data available.")
            }
        }
    }
}

@Composable
fun SummaryCard(label: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(label, style = MaterialTheme.typography.bodyMedium)
            Spacer(modifier = Modifier.height(6.dp))
            Text(value, style = MaterialTheme.typography.headlineSmall)
        }
    }
}

private fun createTempImageUri(context: Context): Uri {
    val directory = File(context.cacheDir, "scan_images").apply { mkdirs() }
    val imageFile = File.createTempFile("cage-card-", ".jpg", directory)
    return FileProvider.getUriForFile(
        context,
        "${context.packageName}.fileprovider",
        imageFile
    )
}
