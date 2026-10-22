package com.example.chinesegame.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.chinesegame.android.ui.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = application as App
        setContent {
            MaterialTheme {
                Surface {
                    val vm: GameViewModel = viewModel(factory = GameViewModel.factory(app))
                    AppNav(vm)
                }
            }
        }
    }
}
