package com.spellwithspeagle.android.service

import android.content.Context
import android.content.Intent
import com.google.android.gms.auth.GoogleAuthUtil
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Lets the app create/read/update only files it creates itself (or ones a
 * user explicitly opens via a Drive picker) -- not broad access to the
 * rest of a family's Drive.
 */
const val DRIVE_FILE_SCOPE = "https://www.googleapis.com/auth/drive.file"

/**
 * Google Sign-In, scoped for Drive access -- the one-time, explicit step
 * [DriveBackupService] needs before it can back up or restore anything.
 * No Firebase or any backend of ours involved: this talks to Google
 * Sign-In and the Drive REST API directly, so a family's data only ever
 * lives in their own Google Drive, never on a server we run.
 */
class AuthService(context: Context) {
    private val appContext = context.applicationContext

    private val googleSignInClient: GoogleSignInClient by lazy {
        val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestEmail()
            .requestScopes(Scope(DRIVE_FILE_SCOPE))
            .build()
        GoogleSignIn.getClient(appContext, options)
    }

    /** The signed-in account, persisted by Google Play Services across app restarts -- null if never signed in or after [signOut]. */
    val currentAccount: GoogleSignInAccount? get() = GoogleSignIn.getLastSignedInAccount(appContext)

    /** Launch this with an [androidx.activity.result.ActivityResultLauncher] for [Intent]. */
    fun signInIntent(): Intent = googleSignInClient.signInIntent

    /** Call from the sign-in launcher's callback with the result [Intent]. */
    suspend fun handleSignInResult(data: Intent?): Result<GoogleSignInAccount> = runCatching {
        GoogleSignIn.getSignedInAccountFromIntent(data).await()
    }

    /**
     * A fresh OAuth2 access token for [DRIVE_FILE_SCOPE], good for Drive
     * REST calls. Fetched new every time rather than cached -- backup/
     * restore are infrequent, one-off actions, and [GoogleAuthUtil]
     * already handles reusing/refreshing the underlying token itself.
     */
    suspend fun driveAccessToken(): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val account = currentAccount?.account ?: error("Not signed in")
            GoogleAuthUtil.getToken(appContext, account, "oauth2:$DRIVE_FILE_SCOPE")
        }
    }

    suspend fun signOut() {
        googleSignInClient.signOut().await()
    }
}
