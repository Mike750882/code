package com.spellwithspeagle.android.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.spellwithspeagle.android.ui.addlist.AddListScreen
import com.spellwithspeagle.android.ui.gate.GateDestination
import com.spellwithspeagle.android.ui.gate.PinGateScreen
import com.spellwithspeagle.android.ui.home.HomeScreen
import com.spellwithspeagle.android.ui.home.PracticeOrTest
import com.spellwithspeagle.android.ui.practice.PracticeScreen
import com.spellwithspeagle.android.ui.profiles.AddChildScreen
import com.spellwithspeagle.android.ui.profiles.ProfilesScreen
import com.spellwithspeagle.android.ui.rewards.RewardsScreen
import com.spellwithspeagle.android.ui.settings.SettingsScreen
import com.spellwithspeagle.android.ui.wordlist.WordListScreen

private object Routes {
    const val ADD_CHILD = "add_child"
    const val ADD_CHILD_SIBLING = "add_child_sibling"
    const val HOME = "home"
    const val PRACTICE = "practice/{mode}?restrictTo={restrictTo}"
    const val GATE = "gate/{destination}"
    const val ADD_LIST = "add_list"
    const val REWARDS = "rewards"
    const val SETTINGS = "settings"
    const val PROFILES = "profiles"
    const val WORD_LIST = "word_list"

    fun practice(mode: PracticeOrTest, restrictToWordIds: List<String>?): String {
        val restrict = restrictToWordIds?.joinToString(",").orEmpty()
        return "practice/${mode.name}?restrictTo=$restrict"
    }

    fun gate(destination: GateDestination): String = "gate/${destination.name}"
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
            HomeScreen(
                onStartSession = { mode, restrictToWordIds ->
                    navController.navigate(Routes.practice(mode, restrictToWordIds))
                },
                onOpenGated = { destination ->
                    navController.navigate(Routes.gate(destination))
                },
                onOpenWordList = { navController.navigate(Routes.WORD_LIST) }
            )
        }
        composable(Routes.WORD_LIST) {
            WordListScreen(onBack = { navController.popBackStack() })
        }
        composable(Routes.ADD_CHILD_SIBLING) {
            AddChildScreen(onChildAdded = { navController.popBackStack(Routes.HOME, inclusive = false) })
        }
        composable(Routes.PROFILES) {
            ProfilesScreen(
                onAddStudent = { navController.navigate(Routes.ADD_CHILD_SIBLING) },
                onProfileSwitched = { navController.popBackStack(Routes.HOME, inclusive = false) },
                onBack = { navController.popBackStack() }
            )
        }
        composable(
            route = Routes.GATE,
            arguments = listOf(navArgument("destination") { type = NavType.StringType })
        ) { backStackEntry ->
            val destinationArg = backStackEntry.arguments?.getString("destination").orEmpty()
            val destination = runCatching { GateDestination.valueOf(destinationArg) }.getOrDefault(GateDestination.SETTINGS)
            PinGateScreen(
                destination = destination,
                onSuccess = { succeeded ->
                    navController.popBackStack()
                    when (succeeded) {
                        GateDestination.ADD_LIST -> navController.navigate(Routes.ADD_LIST)
                        GateDestination.REWARDS -> navController.navigate(Routes.REWARDS)
                        GateDestination.SETTINGS -> navController.navigate(Routes.SETTINGS)
                        // Change-PIN is launched from inside Settings; popping the gate
                        // already lands back there, nothing further to navigate to.
                        GateDestination.CHANGE_PIN -> {}
                    }
                },
                onCancel = { navController.popBackStack() }
            )
        }
        composable(Routes.ADD_LIST) {
            AddListScreen(onDone = { navController.popBackStack(Routes.HOME, inclusive = false) })
        }
        composable(Routes.REWARDS) {
            RewardsScreen(onDone = { navController.popBackStack(Routes.HOME, inclusive = false) })
        }
        composable(Routes.SETTINGS) {
            SettingsScreen(
                onChangePin = { navController.navigate(Routes.gate(GateDestination.CHANGE_PIN)) },
                onOpenProfiles = { navController.navigate(Routes.PROFILES) },
                onBack = { navController.popBackStack(Routes.HOME, inclusive = false) }
            )
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
