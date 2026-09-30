package com.spellwithspeagle.android.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.spellwithspeagle.android.ui.home.HomeScreen
import com.spellwithspeagle.android.ui.home.PracticeOrTest
import com.spellwithspeagle.android.ui.practice.PracticeScreen
import com.spellwithspeagle.android.ui.profiles.AddChildScreen

private object Routes {
    const val ADD_CHILD = "add_child"
    const val HOME = "home"
    const val PRACTICE = "practice/{mode}?restrictTo={restrictTo}"

    fun practice(mode: PracticeOrTest, restrictToWordIds: List<String>?): String {
        val restrict = restrictToWordIds?.joinToString(",").orEmpty()
        return "practice/${mode.name}?restrictTo=$restrict"
    }
}

/**
 * [hasChildren] decides the start destination: a brand-new install with no
 * profiles goes straight to [AddChildScreen], no PIN gate -- there's
 * nothing to protect yet.
 */
@Composable
fun SpellNavHost(hasChildren: Boolean) {
    val navController = rememberNavController()
    val startDestination = if (hasChildren) Routes.HOME else Routes.ADD_CHILD

    NavHost(navController = navController, startDestination = startDestination) {
        composable(Routes.ADD_CHILD) {
            AddChildScreen(onChildAdded = {
                navController.navigate(Routes.HOME) {
                    popUpTo(Routes.ADD_CHILD) { inclusive = true }
                }
            })
        }
        composable(Routes.HOME) {
            HomeScreen(onStartSession = { mode, restrictToWordIds ->
                navController.navigate(Routes.practice(mode, restrictToWordIds))
            })
        }
        composable(
            route = Routes.PRACTICE,
            // "mode"/"restrictTo" aren't read here -- they land in
            // PracticeViewModel's SavedStateHandle automatically, since the
            // ViewModel is scoped to this NavBackStackEntry.
            arguments = listOf(
                navArgument("mode") { type = NavType.StringType },
                navArgument("restrictTo") { type = NavType.StringType; defaultValue = "" }
            )
        ) {
            PracticeScreen(
                onGoHome = {
                    navController.navigate(Routes.HOME) {
                        popUpTo(Routes.HOME) { inclusive = true }
                    }
                }
            )
        }
    }
}
