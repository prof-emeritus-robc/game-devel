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
