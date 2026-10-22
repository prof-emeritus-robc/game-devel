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
