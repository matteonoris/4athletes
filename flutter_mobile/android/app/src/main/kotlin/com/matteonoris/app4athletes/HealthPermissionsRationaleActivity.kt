package com.matteonoris.app4athletes

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast

/** Shows the public notice without authenticating or starting any health-data imports. */
class HealthPermissionsRationaleActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var loading: View
    private lateinit var errorPanel: View
    private var failed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_health_privacy)

        val root = findViewById<View>(R.id.health_privacy_root)
        root.setOnApplyWindowInsetsListener { view, insets ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val bars = insets.getInsets(
                    WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()
                )
                view.setPadding(bars.left, bars.top, bars.right, bars.bottom)
            } else {
                @Suppress("DEPRECATION")
                view.setPadding(
                    insets.systemWindowInsetLeft, insets.systemWindowInsetTop,
                    insets.systemWindowInsetRight, insets.systemWindowInsetBottom
                )
            }
            insets
        }
        root.requestApplyInsets()

        webView = findViewById(R.id.health_privacy_webview)
        loading = findViewById(R.id.health_privacy_loading)
        errorPanel = findViewById(R.id.health_privacy_error)
        findViewById<View>(R.id.health_privacy_close).setOnClickListener { finish() }
        findViewById<View>(R.id.health_privacy_retry).setOnClickListener { loadNotice() }
        findViewById<View>(R.id.health_privacy_browser).setOnClickListener {
            openExternal(Uri.parse(PRIVACY_URL))
        }

        // The public HTML notice does not need scripts, device files, or native bridges.
        webView.settings.apply {
            javaScriptEnabled = false
            allowFileAccess = false
            allowContentAccess = false
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView, request: WebResourceRequest
            ): Boolean {
                if (isNoticeUrl(request.url)) return false
                if (request.isForMainFrame) openExternal(request.url)
                return true
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                loading.visibility = View.VISIBLE
            }

            override fun onPageFinished(view: WebView, url: String?) {
                loading.visibility = View.GONE
                if (!failed) webView.visibility = View.VISIBLE
            }

            override fun onReceivedError(
                view: WebView, request: WebResourceRequest, error: WebResourceError
            ) {
                if (request.isForMainFrame) showLoadError()
            }

            override fun onReceivedHttpError(
                view: WebView, request: WebResourceRequest, response: WebResourceResponse
            ) {
                if (request.isForMainFrame) showLoadError()
            }
        }

        // Never accept an incoming URL: both Health Connect intents show this exact notice.
        loadNotice()
    }

    private fun loadNotice() {
        failed = false
        errorPanel.visibility = View.GONE
        webView.visibility = View.INVISIBLE
        loading.visibility = View.VISIBLE
        webView.loadUrl(PRIVACY_URL)
    }

    private fun showLoadError() {
        failed = true
        loading.visibility = View.GONE
        webView.visibility = View.GONE
        errorPanel.visibility = View.VISIBLE
    }

    private fun isNoticeUrl(uri: Uri): Boolean =
        uri.scheme == "https" && uri.host == "matteonoris.github.io" &&
            uri.port == -1 && uri.encodedPath == "/4athletes/privacy/"

    private fun openExternal(uri: Uri) {
        if (uri.scheme != "https" && uri.scheme != "mailto") return
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            })
        } catch (_: ActivityNotFoundException) {
            Toast.makeText(this, R.string.health_privacy_no_browser, Toast.LENGTH_LONG).show()
        }
    }

    override fun onDestroy() {
        webView.stopLoading()
        webView.destroy()
        super.onDestroy()
    }

    companion object {
        // Keep identical to lib/core/legal_links.dart and the Play Console privacy URL.
        private const val PRIVACY_URL = "https://matteonoris.github.io/4athletes/privacy/"
    }
}
