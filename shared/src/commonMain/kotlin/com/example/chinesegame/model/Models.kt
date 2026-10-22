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
