package com.example.chinesegame.data

import com.example.chinesegame.model.SeedFile
import kotlinx.serialization.json.Json

class SeedLoader(private val json: String) {
    fun load(): SeedFile = Json { ignoreUnknownKeys = true }.decodeFromString(json)
}
