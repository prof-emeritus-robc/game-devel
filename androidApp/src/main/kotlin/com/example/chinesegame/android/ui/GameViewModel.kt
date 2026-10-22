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
