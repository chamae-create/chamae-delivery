package br.com.loumak.chamae

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                "chamae_orders_high",
                "Atualizações de Pedidos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações em tempo real do status dos pedidos Chamaê Delivery"
                enableVibration(true)
            }
            manager?.createNotificationChannel(channel)
        }
    }
}
