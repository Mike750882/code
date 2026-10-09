package com.spellwithspeagle.android.service

import android.content.Context
import android.content.Intent
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.spellwithspeagle.android.R
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

/**
 * Google Sign-In + Firebase Auth, the sign-in step [SyncService] needs
 * before it can sync anything -- there's no Android equivalent of "already
 * signed into iCloud," so this is a one-time, explicit, opt-in step instead
 * of iOS's always-on CloudKit sync.
 */
class AuthService(context: Context) {
    private val appContext = context.applicationContext
    private val auth = FirebaseAuth.getInstance()

    private val googleSignInClient: GoogleSignInClient by lazy {
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(appContext.getString(R.string.default_web_client_id))
            .requestEmail()
            .build()
        GoogleSignIn.getClient(appContext, options)
    }

    val currentUser: FirebaseUser? get() = auth.currentUser

    /** Emits the signed-in user (or null) immediately and on every sign-in/sign-out. */
    val authState: Flow<FirebaseUser?> = callbackFlow {
        val listener = FirebaseAuth.AuthStateListener { trySend(it.currentUser) }
        auth.addAuthStateListener(listener)
        awaitClose { auth.removeAuthStateListener(listener) }
    }

    /** Launch this with an [androidx.activity.result.ActivityResultLauncher] for [Intent]. */
    fun signInIntent(): Intent = googleSignInClient.signInIntent

    /** Call from the sign-in launcher's callback with the result [Intent]. */
    suspend fun handleSignInResult(data: Intent?): Result<FirebaseUser> = runCatching {
        val account = GoogleSignIn.getSignedInAccountFromIntent(data).await()
        val idToken = account.idToken ?: error("Google account returned no ID token")
        val credential = GoogleAuthProvider.getCredential(idToken, null)
        val result = auth.signInWithCredential(credential).await()
        result.user ?: error("Firebase sign-in returned no user")
    }

    suspend fun signOut() {
        auth.signOut()
        googleSignInClient.signOut().await()
    }
}
