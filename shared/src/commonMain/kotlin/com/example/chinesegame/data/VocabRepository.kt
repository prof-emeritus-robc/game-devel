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
