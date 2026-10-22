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
