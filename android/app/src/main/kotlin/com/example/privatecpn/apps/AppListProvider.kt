package com.example.privatecpn.apps

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

data class InstalledAppItem(
    val name: String,
    val packageName: String,
    val iconBase64: String?,
    val isSystemApp: Boolean
)

object AppListProvider {

    suspend fun getInstalledApps(context: Context): List<Map<String, Any?>> = withContext(Dispatchers.IO) {
        val packageManager = context.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

        val resolveInfos = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                mainIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_ALL.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.queryIntentActivities(mainIntent, 0)
        }

        val seenPackages = mutableSetOf<String>()
        val appList = mutableListOf<Map<String, Any?>>()
        val ownPackageName = context.packageName

        for (resolveInfo in resolveInfos) {
            val pkgName = resolveInfo.activityInfo.packageName
            if (pkgName == ownPackageName || seenPackages.contains(pkgName)) {
                continue
            }
            seenPackages.add(pkgName)

            val appName = resolveInfo.loadLabel(packageManager).toString()
            val isSystem = try {
                val appInfo = packageManager.getApplicationInfo(pkgName, 0)
                (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            } catch (e: Exception) {
                false
            }

            val iconBase64 = try {
                val drawable = resolveInfo.loadIcon(packageManager)
                val bitmap = drawableToBitmap(drawable)
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
                val bytes = stream.toByteArray()
                Base64.encodeToString(bytes, Base64.NO_WRAP)
            } catch (e: Exception) {
                null
            }

            appList.add(
                mapOf(
                    "name" to appName,
                    "packageName" to pkgName,
                    "icon" to iconBase64,
                    "isSystemApp" to isSystem
                )
            )
        }

        appList.sortedBy { (it["name"] as? String)?.lowercase() ?: "" }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            val bmp = drawable.bitmap
            if (bmp.width > 0 && bmp.height > 0) {
                // Resize if too large to save memory
                val maxDim = 96
                if (bmp.width > maxDim || bmp.height > maxDim) {
                    return Bitmap.createScaledBitmap(bmp, maxDim, maxDim, true)
                }
                return bmp
            }
        }

        val width = if (drawable.intrinsicWidth > 0) Math.min(drawable.intrinsicWidth, 96) else 96
        val height = if (drawable.intrinsicHeight > 0) Math.min(drawable.intrinsicHeight, 96) else 96
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}
