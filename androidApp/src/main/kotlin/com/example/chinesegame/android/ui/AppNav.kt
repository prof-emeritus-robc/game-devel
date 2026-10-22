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
