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
