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
