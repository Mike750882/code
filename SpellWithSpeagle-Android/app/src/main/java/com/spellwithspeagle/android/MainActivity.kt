package com.spellwithspeagle.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.spellwithspeagle.android.data.model.Child
import com.spellwithspeagle.android.navigation.SpellNavHost
import com.spellwithspeagle.android.ui.theme.ColorProfile
import com.spellwithspeagle.android.ui.theme.SpellWithSpeagleTheme
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val app = application as SpellWithSpeagleApp

        setContent {
            val activeChild by activeChildFlow(app).collectAsStateWithLifecycle(initialValue = LoadState.Loading)
            val colorProfile = when (val state = activeChild) {
                is LoadState.Ready -> ColorProfile.byId(state.child?.colorProfile)
                else -> ColorProfile.Default
            }

            SpellWithSpeagleTheme(colorProfile = colorProfile) {
                Surface(modifier = Modifier.fillMaxSize(), color = androidx.compose.ui.graphics.Color.Transparent) {
                    when (val state = activeChild) {
                        is LoadState.Loading -> LoadingIndicator()
                        is LoadState.Ready -> SpellNavHost(hasChildren = state.hasChildren)
                    }
                }
            }
        }
    }
}

private sealed interface LoadState {
    data object Loading : LoadState
    data class Ready(val hasChildren: Boolean, val child: Child?) : LoadState
}

private fun activeChildFlow(app: SpellWithSpeagleApp) =
    combine(
        app.repository.observeChildren(),
        app.activeChildStore.activeChildId
    ) { children, activeId ->
        val active = children.firstOrNull { it.id == activeId } ?: children.firstOrNull()
        LoadState.Ready(hasChildren = children.isNotEmpty(), child = active) as LoadState
    }.distinctUntilChanged()

@Composable
private fun LoadingIndicator() {
    androidx.compose.foundation.layout.Box(modifier = Modifier.fillMaxSize()) {
        CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
    }
}
