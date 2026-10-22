#!/usr/bin/env bash
set -euo pipefail

# ---------- root ----------
mkdir -p shared/src/commonMain/kotlin/com/example/chinesegame/{model,db,data,domain}
mkdir -p shared/src/commonMain/sqldelight/com/example/chinesegame/db
mkdir -p androidApp/src/main/kotlin/com/example/chinesegame/android/{di,ui}
mkdir -p androidApp/src/main/assets
mkdir -p .github/workflows

cat > settings.gradle.kts <<'EOF'
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "chinesegame"
include(":shared", ":androidApp")
EOF

cat > build.gradle.kts <<'EOF'
plugins {
    kotlin("multiplatform") version "1.9.24" apply false
    kotlin("android") version "1.9.24" apply false
    id("com.android.library") version "8.5.0" apply false
    id("com.android.application") version "8.5.0" apply false
    id("app.cash.sqldelight") version "2.0.1" apply false
    kotlin("plugin.serialization") version "1.9.24" apply false
}
EOF

cat > gradle.properties <<'EOF'
kotlin.code.style=official
android.useAndroidX=true
kotlin.mpp.androidSourceSetLayoutVersion=2
org.gradle.jvmargs=-Xmx2048m
EOF

cat > .gitignore <<'EOF'
.gradle/
build/
local.properties
*.iml
.idea/
.DS_Store
captures/
EOF

# ---------- shared ----------
cat > shared/build.gradle.kts <<'EOF'
plugins {
    kotlin("multiplatform")
    kotlin("plugin.serialization")
    id("com.android.library")
    id("app.cash.sqldelight")
}

kotlin {
    androidTarget()
    sourceSets {
        val commonMain by getting {
            dependencies {
                implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
                implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
                implementation("app.cash.sqldelight:runtime:2.0.1")
                implementation("app.cash.sqldelight:coroutines-extensions:2.0.1")
            }
        }
        val androidMain by getting {
            dependencies {
                implementation("app.cash.sqldelight:android-driver:2.0.1")
            }
        }
    }
}

android {
    namespace = "com.example.chinesegame.shared"
    compileSdk = 34
    defaultConfig { minSdk = 26 }
}

sqldelight {
    databases {
        create("VocabDatabase") {
            packageName.set("com.example.chinesegame.db")
        }
    }
}
EOF

cat > shared/src/commonMain/sqldelight/com/example/chinesegame/db/Vocab.sq <<'EOF'
CREATE TABLE domain (
    id TEXT NOT NULL PRIMARY KEY,
    enName TEXT NOT NULL,
    zhName TEXT NOT NULL
);

CREATE TABLE term (
    id TEXT NOT NULL PRIMARY KEY,
    domainId TEXT NOT NULL,
    zh TEXT NOT NULL,
    pinyin TEXT NOT NULL,
    en TEXT NOT NULL,
    level INTEGER NOT NULL,
    audioUri TEXT
);
CREATE INDEX term_domain ON term(domainId);

CREATE TABLE progress (
    termId TEXT NOT NULL PRIMARY KEY,
    ease REAL NOT NULL DEFAULT 2.5,
    intervalDays INTEGER NOT NULL DEFAULT 0,
    dueAt INTEGER NOT NULL DEFAULT 0,
    correctCount INTEGER NOT NULL DEFAULT 0,
    wrongCount INTEGER NOT NULL DEFAULT 0
);

selectDomains:
SELECT * FROM domain;

selectTermsByDomain:
SELECT * FROM term WHERE domainId = ?;

selectAllTerms:
SELECT * FROM term;

selectTermById:
SELECT * FROM term WHERE id = ?;

insertDomain:
INSERT OR REPLACE INTO domain(id, enName, zhName) VALUES (?, ?, ?);

insertTerm:
INSERT OR REPLACE INTO term(id, domainId, zh, pinyin, en, level, audioUri)
VALUES (?, ?, ?, ?, ?, ?, ?);

countTerms:
SELECT COUNT(*) FROM term;

selectProgress:
SELECT * FROM progress WHERE termId = ?;

upsertProgress:
INSERT OR REPLACE INTO progress(termId, ease, intervalDays, dueAt, correctCount, wrongCount)
VALUES (?, ?, ?, ?, ?, ?);
EOF

cat > shared/src/commonMain/kotlin/com/example/chinesegame/model/Models.kt <<'EOF'
package com.example.chinesegame.model

import kotlinx.serialization.Serializable

@Serializable data class Domain(val id: String, val enName: String, val zhName: String)
@Serializable data class Term(
    val id: String, val domainId: String, val zh: String,
    val pinyin: String, val en: String, val level: Int,
    val audioUri: String? = null
)
@Serializable data class SeedFile(val domains: List<Domain>, val terms: List<Term>)

data class QuizItem(
    val termId: String, val prompt: String, val pinyin: String,
    val correct: String, val distractors: List<String>
)
data class ProgressState(
    val termId: String, val ease: Float, val intervalDays: Int,
    val dueAt: Long, val correctCount: Int, val wrongCount: Int
)
data class MockComponent(val type: String, val label: String, val domainId: String)
EOF

cat > shared/src/commonMain/kotlin/com/example/chinesegame/domain/ComputeSRS.kt <<'EOF'
package com.example.chinesegame.domain

import com.example.chinesegame.model.ProgressState

class ComputeSRS {
    fun isDue(p: ProgressState, now: Long) = p.dueAt <= now
    fun next(p: ProgressState, correct: Boolean, now: Long): ProgressState {
        val ease = if (correct) minOf(p.ease + 0.1f, 2.8f) else maxOf(p.ease - 0.2f, 1.3f)
        val interval = when {
            !correct -> 1
            p.intervalDays == 0 -> 1
            p.intervalDays == 1 -> 3
            else -> (p.intervalDays * ease).toInt()
        }
        return p.copy(
            ease = ease, intervalDays = interval,
            dueAt = now + interval * 86_400_000L,
            correctCount = p.correctCount + if (correct) 1 else 0,
            wrongCount = p.wrongCount + if (!correct) 1 else 0
        )
    }
}
EOF

cat > shared/src/commonMain/kotlin/com/example/chinesegame/domain/GetQuizSession.kt <<'EOF'
package com.example.chinesegame.domain

import com.example.chinesegame.data.VocabRepository
import com.example.chinesegame.model.QuizItem

class GetQuizSession(
    private val repo: VocabRepository,
    private val srs: ComputeSRS
) {
    suspend fun invoke(domainId: String?, count: Int = 10, now: Long): List<QuizItem> {
        val all = repo.getTerms(domainId)
        val due = all.filter { srs.isDue(repo.getProgress(it.id), now) }.shuffled()
        val pool = (due + all.shuffled()).distinctBy { it.id }.take(count)
        return pool.map { t ->
            val distractors = all.asSequence()
                .filter { it.id != t.id }.map { it.en }.distinct()
                .shuffled().take(3).toList()
            QuizItem(t.id, t.zh, t.pinyin, t.en, distractors)
        }
    }
}
EOF

cat > shared/src/commonMain/kotlin/com/example/chinesegame/domain/GenerateMockFromText.kt <<'EOF'
package com.example.chinesegame.domain

import com.example.chinesegame.model.MockComponent
import com.example.chinesegame.model.Term

// Stub for v1.1 capture-to-generate. Pure logic, unit-tested, unused in v1 UI.
class GenerateMockFromText {
    fun invoke(ocrText: String, knownTerms: List<Term>, domainId: String): List<MockComponent> =
        knownTerms
            .filter { it.domainId == domainId && ocrText.contains(it.zh) }
            .map { MockComponent("button", it.zh, it.domainId) }
}
EOF

cat > shared/src/commonMain/kotlin/com/example/chinesegame/data/VocabRepository.kt <<'EOF'
package com.example.chinesegame.data

import com.example.chinesegame.db.VocabDatabase
import com.example.chinesegame.model.*

class VocabRepository(private val db: VocabDatabase, private val now: () -> Long) {
    fun getDomains(): List<Domain> =
        db.vocabQueries.selectDomains().executeAsList()
            .map { Domain(it.id, it.enName, it.zhName) }

    fun getTerms(domainId: String?): List<Term> {
        val rows = if (domainId == null) db.vocabQueries.selectAllTerms().executeAsList()
                   else db.vocabQueries.selectTermsByDomain(domainId).executeAsList()
        return rows.map { Term(it.id, it.domainId, it.zh, it.pinyin, it.en, it.level.toInt(), it.audioUri) }
    }

    fun getProgress(termId: String): ProgressState {
        val row = db.vocabQueries.selectProgress(termId).executeAsOneOrNull()
        return row?.let {
            ProgressState(it.termId, it.ease.toFloat(), it.intervalDays.toInt(),
                          it.dueAt, it.correctCount.toInt(), it.wrongCount.toInt())
        } ?: ProgressState(termId, 2.5f, 0, 0L, 0, 0)
    }

    fun saveProgress(p: ProgressState) {
        db.vocabQueries.upsertProgress(
            p.termId, p.ease.toDouble(), p.intervalDays.toLong(),
            p.dueAt, p.correctCount.toLong(), p.wrongCount.toLong())
    }

    fun isSeeded(): Boolean = db.vocabQueries.countTerms().executeAsOne() > 0

    fun seed(data: SeedFile) {
        db.transaction {
            data.domains.forEach { db.vocabQueries.insertDomain(it.id, it.enName, it.zhName) }
            data.terms.forEach {
                db.vocabQueries.insertTerm(it.id, it.domainId, it.zh, it.pinyin,
                                           it.en, it.level.toLong(), it.audioUri)
            }
        }
    }
}
EOF

cat > shared/src/commonMain/kotlin/com/example/chinesegame/data/SeedLoader.kt <<'EOF'
package com.example.chinesegame.data

import com.example.chinesegame.model.SeedFile
import kotlinx.serialization.json.Json

class SeedLoader(private val json: String) {
    fun load(): SeedFile = Json { ignoreUnknownKeys = true }.decodeFromString(json)
}
EOF

# ---------- androidApp ----------
cat > androidApp/build.gradle.kts <<'EOF'
plugins {
    id("com.android.application")
    kotlin("android")
    kotlin("plugin.serialization")
}
android {
    namespace = "com.example.chinesegame.android"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.example.chinesegame"
        minSdk = 26; targetSdk = 34
        versionCode = 1; versionName = "0.1"
    }
    buildFeatures { compose = true }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    implementation(project(":shared"))
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
EOF

cat > androidApp/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
        android:name=".App"
        android:label="Chinese UI Trainer"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/App.kt <<'EOF'
package com.example.chinesegame.android

import android.app.Application
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import com.example.chinesegame.data.*
import com.example.chinesegame.db.VocabDatabase
import com.example.chinesegame.domain.*

class App : Application() {
    lateinit var repo: VocabRepository
    lateinit var quiz: GetQuizSession
    lateinit var srs: ComputeSRS

    override fun onCreate() {
        super.onCreate()
        val driver = AndroidSqliteDriver(VocabDatabase.Schema, this, "vocab.db")
        val db = VocabDatabase(driver)
        repo = VocabRepository(db) { System.currentTimeMillis() }
        srs = ComputeSRS()
        quiz = GetQuizSession(repo, srs)

        if (!repo.isSeeded()) {
            val json = assets.open("seed.json").bufferedReader().use { it.readText() }
            repo.seed(SeedLoader(json).load())
        }
    }
}
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/MainActivity.kt <<'EOF'
package com.example.chinesegame.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.chinesegame.android.ui.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = application as App
        setContent {
            MaterialTheme {
                Surface {
                    val vm: GameViewModel = viewModel(factory = GameViewModel.factory(app))
                    AppNav(vm)
                }
            }
        }
    }
}
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/ui/GameViewModel.kt <<'EOF'
package com.example.chinesegame.android.ui

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.chinesegame.android.App
import com.example.chinesegame.model.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

sealed interface Screen {
    data object Home : Screen
    data class Game(val items: List<QuizItem>, val domainId: String?) : Screen
    data class Result(val score: Int, val total: Int, val wrong: List<QuizItem>) : Screen
}

class GameViewModel(private val app: App) : ViewModel() {
    private val _screen = MutableStateFlow<Screen>(Screen.Home)
    val screen: StateFlow<Screen> = _screen
    val domains = app.repo.getDomains()

    fun startGame(domainId: String?) = viewModelScope.launch {
        val items = app.quiz.invoke(domainId, 10, System.currentTimeMillis())
        _screen.value = Screen.Game(items, domainId)
    }

    fun recordAnswer(item: QuizItem, correct: Boolean) {
        val now = System.currentTimeMillis()
        val p = app.repo.getProgress(item.termId)
        app.repo.saveProgress(app.srs.next(p, correct, now))
    }

    fun finish(items: List<QuizItem>, answers: Map<String, Boolean>) {
        val wrong = items.filter { answers[it.termId] == false }
        _screen.value = Screen.Result(answers.count { it.value }, items.size, wrong)
    }

    fun home() { _screen.value = Screen.Home }

    companion object {
        fun factory(app: App) = object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = GameViewModel(app) as T
        }
    }
}
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/ui/AppNav.kt <<'EOF'
package com.example.chinesegame.android.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue

@Composable
fun AppNav(vm: GameViewModel) {
    val screen by vm.screen.collectAsState()
    when (val s = screen) {
        Screen.Home -> HomeScreen(vm.domains) { vm.startGame(it) }
        is Screen.Game -> CharacterMatchScreen(
            items = s.items,
            onAnswer = vm::recordAnswer,
            onFinish = { answers -> vm.finish(s.items, answers) }
        )
        is Screen.Result -> ResultScreen(s.score, s.total, s.wrong) { vm.home() }
    }
}
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/ui/HomeScreen.kt <<'EOF'
package com.example.chinesegame.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.chinesegame.model.Domain

@Composable
fun HomeScreen(domains: List<Domain>, onStart: (String?) -> Unit) {
    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Text("Chinese UI Trainer", fontSize = 28.sp)
        Spacer(Modifier.height(8.dp))
        Text("Recognize the characters you'll meet in Chinese apps.",
             fontSize = 14.sp, color = MaterialTheme.colorScheme.outline)
        Spacer(Modifier.height(24.dp))
        Button(onClick = { onStart(null) }, modifier = Modifier.fillMaxWidth()) {
            Text("Review all domains")
        }
        Spacer(Modifier.height(24.dp))
        Text("By domain", fontSize = 18.sp)
        Spacer(Modifier.height(8.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(domains) { d ->
                OutlinedButton(onClick = { onStart(d.id) },
                    modifier = Modifier.fillMaxWidth().height(64.dp)) {
                    Column {
                        Text(d.enName, fontSize = 18.sp)
                        Text(d.zhName, fontSize = 14.sp,
                             color = MaterialTheme.colorScheme.outline)
                    }
                }
            }
        }
    }
}
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/ui/CharacterMatchScreen.kt <<'EOF'
package com.example.chinesegame.android.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.chinesegame.model.QuizItem

@Composable
fun CharacterMatchScreen(
    items: List<QuizItem>,
    onAnswer: (QuizItem, Boolean) -> Unit,
    onFinish: (Map<String, Boolean>) -> Unit
) {
    var idx by remember { mutableIntStateOf(0) }
    var showPinyin by remember { mutableStateOf(false) }
    val answers = remember { mutableStateMapOf<String, Boolean>() }
    val item = items[idx]

    Column(Modifier.fillMaxSize().padding(24.dp),
           horizontalAlignment = Alignment.CenterHorizontally) {
        LinearProgressIndicator(
            progress = { (idx + 1f) / items.size },
            modifier = Modifier.fillMaxWidth())
        Text("${idx + 1} / ${items.size}",
             style = MaterialTheme.typography.labelMedium)

        Spacer(Modifier.height(48.dp))

        Box(Modifier.clickable { showPinyin = !showPinyin }.padding(12.dp)) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(item.prompt, fontSize = 56.sp, fontWeight = FontWeight.Medium)
                if (showPinyin) {
                    Text(item.pinyin, fontSize = 20.sp,
                         color = MaterialTheme.colorScheme.primary,
                         modifier = Modifier.padding(top = 8.dp))
                } else {
                    Text("tap for pinyin", fontSize = 12.sp,
                         color = MaterialTheme.colorScheme.outline,
                         modifier = Modifier.padding(top = 8.dp))
                }
            }
        }

        Spacer(Modifier.height(48.dp))

        (item.distractors + item.correct).shuffled().forEach { choice ->
            OutlinedButton(
                onClick = {
                    val ok = choice == item.correct
                    answers[item.termId] = ok
                    onAnswer(item, ok)
                    showPinyin = false
                    if (idx == items.lastIndex) onFinish(answers.toMap()) else idx++
                },
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)
            ) { Text(choice, fontSize = 18.sp) }
        }
    }
}
EOF

cat > androidApp/src/main/kotlin/com/example/chinesegame/android/ui/ResultScreen.kt <<'EOF'
package com.example.chinesegame.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.r
