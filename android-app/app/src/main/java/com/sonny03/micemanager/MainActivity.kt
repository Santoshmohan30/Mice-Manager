package com.sonny03.micemanager

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
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
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
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
                MobileApp(viewModel = viewModel)
            }
        }
    }
}

data class MouseSummary(
    val id: Int,
    val strain: String,
    val cage: String,
    val genotype: String,
    val training: Boolean
)

data class DashboardSummary(
    val totalMice: Int,
    val totalStrains: Int,
    val trainingMice: Int
)

class MobileRepository {
    private val baseUrl = "http://192.168.1.151:8000"

    suspend fun login(username: String, password: String): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val payload = JSONObject()
                .put("username", username)
                .put("password", password)

            val connection = URL("$baseUrl/api/login").openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
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
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("Failed to load dashboard")
            }

            val stats = JSONObject(body).getJSONObject("stats")
            DashboardSummary(
                totalMice = stats.getInt("total_mice"),
                totalStrains = stats.getInt("strains"),
                trainingMice = stats.getInt("training_mice")
            )
        }
    }

    suspend fun mice(token: String): Result<List<MouseSummary>> = withContext(Dispatchers.IO) {
        runCatching {
            val connection = authedConnection("$baseUrl/api/mice", token)
            val body = connection.readBody()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException("Failed to load mice")
            }

            val items = JSONArray(body)
            buildList {
                for (index in 0 until items.length()) {
                    val item = items.getJSONObject(index)
                    add(
                        MouseSummary(
                            id = item.getInt("id"),
                            strain = item.getString("strain"),
                            cage = item.getString("cage"),
                            genotype = item.getString("genotype"),
                            training = item.getBoolean("training")
                        )
                    )
                }
            }
        }
    }

    private fun authedConnection(url: String, token: String): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.setRequestProperty("Authorization", "Bearer $token")
        return connection
    }

    private fun HttpURLConnection.readBody(): String {
        val stream = if (responseCode in 200..299) inputStream else errorStream
        return BufferedReader(stream.reader()).use { it.readText() }
    }
}

class MobileViewModel(private val repository: MobileRepository) : ViewModel() {
    var username by mutableStateOf("")
    var password by mutableStateOf("")
    var token by mutableStateOf<String?>(null)
    var summary by mutableStateOf<DashboardSummary?>(null)
    var mice by mutableStateOf(emptyList<MouseSummary>())
    var errorMessage by mutableStateOf<String?>(null)
    var isLoading by mutableStateOf(false)

    fun signIn() {
        errorMessage = null
        isLoading = true
        viewModelScope.launch {
            repository.login(username, password)
                .onSuccess { signedToken ->
                    token = signedToken
                    loadData()
                }
                .onFailure {
                    isLoading = false
                    errorMessage = it.message
                }
        }
    }

    private fun loadData() {
        val authToken = token ?: return
        viewModelScope.launch {
            val dashboardResult = repository.dashboard(authToken)
            val miceResult = repository.mice(authToken)

            dashboardResult.onSuccess { summary = it }
            miceResult.onSuccess { mice = it }

            val error = dashboardResult.exceptionOrNull()?.message ?: miceResult.exceptionOrNull()?.message
            errorMessage = error
            isLoading = false
        }
    }
}

class MobileViewModelFactory(
    private val repository: MobileRepository
) : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return MobileViewModel(repository) as T
    }
}

@Composable
fun MobileApp(viewModel: MobileViewModel) {
    if (viewModel.token == null) {
        LoginScreen(viewModel = viewModel)
    } else {
        DashboardScreen(viewModel = viewModel)
    }
}

@Composable
fun LoginScreen(viewModel: MobileViewModel) {
    var baseUrlHelp by remember { mutableStateOf("Use 10.0.2.2 for emulator. Use your computer's LAN IP for a real phone.") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.Center
    ) {
        Text("Mice Manager", style = MaterialTheme.typography.headlineMedium)
        Spacer(modifier = Modifier.height(8.dp))
        Text(baseUrlHelp, style = MaterialTheme.typography.bodyMedium)
        Spacer(modifier = Modifier.height(20.dp))
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
            if (viewModel.isLoading) {
                CircularProgressIndicator()
            } else {
                Text("Sign In")
            }
        }
        viewModel.errorMessage?.let {
            Spacer(modifier = Modifier.height(12.dp))
            Text(it, color = MaterialTheme.colorScheme.error)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(viewModel: MobileViewModel) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Mice Manager Mobile") })
        }
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                viewModel.summary?.let { summary ->
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        SummaryCard("Mice", summary.totalMice.toString(), Modifier.weight(1f))
                        SummaryCard("Strains", summary.totalStrains.toString(), Modifier.weight(1f))
                        SummaryCard("Training", summary.trainingMice.toString(), Modifier.weight(1f))
                    }
                }
            }

            items(viewModel.mice) { mouse ->
                Card {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Text("#${mouse.id} · ${mouse.strain}", style = MaterialTheme.typography.titleMedium)
                        Spacer(modifier = Modifier.height(6.dp))
                        Text("Cage ${mouse.cage}")
                        Text("Genotype: ${mouse.genotype}")
                        Text("Training: ${if (mouse.training) "Yes" else "No"}")
                    }
                }
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
