package com.texasswiss.shoplog;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ContentValues;
import android.content.Intent;
import android.graphics.Color;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.webkit.JavascriptInterface;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public final class MainActivity extends Activity {
    private static final String START_URL = "file:///android_asset/shoplog.html";
    private static final int FILE_CHOOSER_REQUEST = 4401;

    private final ExecutorService fileExecutor = Executors.newSingleThreadExecutor();
    private WebView webView;
    private ValueCallback<Uri[]> pendingFileChooser;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(Color.rgb(3, 7, 18));
        getWindow().setNavigationBarColor(Color.rgb(3, 7, 18));

        webView = new WebView(this);
        webView.setBackgroundColor(Color.rgb(3, 7, 18));
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setMediaPlaybackRequiresUserGesture(true);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);

        webView.addJavascriptInterface(new AndroidBridge(), "ShopLogAndroid");
        webView.setWebViewClient(new ShopLogWebViewClient());
        webView.setWebChromeClient(new ShopLogWebChromeClient());

        if (savedInstanceState == null) {
            webView.loadUrl(START_URL);
        } else if (webView.restoreState(savedInstanceState) == null) {
            webView.loadUrl(START_URL);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        webView.saveState(outState);
        super.onSaveInstanceState(outState);
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.removeJavascriptInterface("ShopLogAndroid");
            webView.destroy();
        }
        fileExecutor.shutdown();
        super.onDestroy();
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != FILE_CHOOSER_REQUEST || pendingFileChooser == null) return;

        Uri[] result = null;
        if (resultCode == RESULT_OK && data != null && data.getData() != null) {
            result = new Uri[]{data.getData()};
        }
        pendingFileChooser.onReceiveValue(result);
        pendingFileChooser = null;
    }

    private void openExternal(String rawUrl) {
        try {
            Uri uri = Uri.parse(rawUrl);
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            startActivity(intent);
        } catch (ActivityNotFoundException | IllegalArgumentException error) {
            Toast.makeText(this, "No app can open that link", Toast.LENGTH_SHORT).show();
        }
    }

    private final class ShopLogWebViewClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            return handleUrl(request.getUrl());
        }

        @Override
        public boolean shouldOverrideUrlLoading(WebView view, String url) {
            return handleUrl(Uri.parse(url));
        }

        private boolean handleUrl(Uri uri) {
            String url = uri.toString();
            if (url.startsWith("file:///android_asset/") || url.startsWith("about:blank")) return false;
            String scheme = uri.getScheme();
            if (scheme != null && (
                scheme.equalsIgnoreCase("http") ||
                scheme.equalsIgnoreCase("https") ||
                scheme.equalsIgnoreCase("mailto") ||
                scheme.equalsIgnoreCase("tel")
            )) {
                openExternal(url);
                return true;
            }
            return false;
        }
    }

    private final class ShopLogWebChromeClient extends WebChromeClient {
        @Override
        public boolean onShowFileChooser(
            WebView webView,
            ValueCallback<Uri[]> filePathCallback,
            FileChooserParams fileChooserParams
        ) {
            if (pendingFileChooser != null) pendingFileChooser.onReceiveValue(null);
            pendingFileChooser = filePathCallback;

            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            intent.setType("application/json");
            try {
                startActivityForResult(intent, FILE_CHOOSER_REQUEST);
                return true;
            } catch (ActivityNotFoundException error) {
                pendingFileChooser = null;
                Toast.makeText(MainActivity.this, "No file picker is available", Toast.LENGTH_SHORT).show();
                return false;
            }
        }
    }

    private final class AndroidBridge {
        @JavascriptInterface
        public void saveFile(String rawFilename, String mimeType, String base64Data) {
            final String filename = sanitizeFilename(rawFilename);
            final String safeMime = mimeType == null || mimeType.isBlank()
                ? "application/octet-stream"
                : mimeType;
            fileExecutor.execute(() -> {
                try {
                    byte[] bytes = Base64.decode(base64Data, Base64.DEFAULT);
                    String location = writeExport(filename, safeMime, bytes);
                    runOnUiThread(() -> Toast.makeText(
                        MainActivity.this,
                        "Saved to " + location,
                        Toast.LENGTH_LONG
                    ).show());
                } catch (Exception error) {
                    runOnUiThread(() -> Toast.makeText(
                        MainActivity.this,
                        "Could not save " + filename,
                        Toast.LENGTH_LONG
                    ).show());
                }
            });
        }

        @JavascriptInterface
        public void openExternal(String url) {
            runOnUiThread(() -> MainActivity.this.openExternal(url));
        }
    }

    private String writeExport(String filename, String mimeType, byte[] bytes) throws Exception {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContentValues values = new ContentValues();
            values.put(MediaStore.MediaColumns.DISPLAY_NAME, filename);
            values.put(MediaStore.MediaColumns.MIME_TYPE, mimeType);
            values.put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + File.separator + "ShopLog"
            );
            values.put(MediaStore.MediaColumns.IS_PENDING, 1);

            Uri uri = getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
            if (uri == null) throw new IllegalStateException("Downloads storage unavailable");
            try (OutputStream output = getContentResolver().openOutputStream(uri)) {
                if (output == null) throw new IllegalStateException("Could not open export destination");
                output.write(bytes);
            }
            values.clear();
            values.put(MediaStore.MediaColumns.IS_PENDING, 0);
            getContentResolver().update(uri, values, null, null);
            return "Downloads/ShopLog/" + filename;
        }

        File directory = new File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "ShopLog");
        if (!directory.exists() && !directory.mkdirs()) {
            throw new IllegalStateException("Could not create export folder");
        }
        File target = new File(directory, filename);
        try (OutputStream output = new FileOutputStream(target)) {
            output.write(bytes);
        }
        return target.getAbsolutePath();
    }

    private static String sanitizeFilename(String value) {
        String filename = value == null ? "shoplog-export.bin" : value.trim();
        filename = filename.replaceAll("[\\\\/:*?\"<>|\\r\\n]+", "-");
        if (filename.isBlank()) filename = "shoplog-export.bin";
        return filename.toLowerCase(Locale.ROOT).equals(".") ? "shoplog-export.bin" : filename;
    }
}

