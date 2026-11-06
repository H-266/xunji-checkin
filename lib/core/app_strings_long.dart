/// 长帮助、FAQ 与 ROM 保活说明的翻译表。
///
/// 这些文案较长、出现频率低，单独维护，避免正文表膨胀。
const Map<String, Map<String, String>> longStrings = {
  'en': {
    '为什么第二天打卡状态会重置？': 'Why does the check-in reset the next day?',
    '打卡记录按「任务 + 日期」保存。每日任务在每一天都是新的记录，所以零点后自动回到未完成状态，不需要改写数据库。': 'Check-ins are stored per task and per date. A daily task gets a fresh record each day, so it returns to unchecked after midnight without rewriting the database.',
    '临时待办完成后为什么不见了？': 'Why does a one-off todo disappear after completion?',
    '临时待办是一次性任务。勾选完成后会从今日列表消失，但完成当天仍会计入热力图；可在任务详情里撤销或查看。': 'A one-off todo is a single-use task. Once checked, it leaves today\'s list but still counts for today\'s heatmap. You can undo or inspect it in the task details.',
    '桌面小组件不刷新怎么办？': 'What if the home-screen widget does not refresh?',
    '先在小组件配置页点「立即刷新」。国产 ROM 可能限制后台，请在设置 → 保活帮助里允许后台运行和自启动；零点刷新使用系统非精确闹钟，可能会有几分钟延迟。': 'Tap “Refresh now” on the widget settings page first. Some Chinese ROMs restrict background work, so allow background running and auto-start in Settings → Keep-alive. The midnight refresh uses an inexact alarm and may be a few minutes late.',
    '备份文件在哪里？会申请存储权限吗？':
        'Where is the backup file? Does it need storage permission?',
    '导出时由系统文件选择器决定保存位置，App 只写入你选中的文件，不会申请存储权限。导入会先校验，再让你选择覆盖或追加。': 'The system file picker chooses the location. The app writes only the file you select and never requests storage permission. Import validates first, then lets you overwrite or append.',
    '自动备份什么时候执行？': 'When does automatic backup run?',
    '默认关闭。开启后只在 App 启动或回到前台时检查周期，不会常驻后台；目录由系统文件选择器授权，保留份数可自选。最近一次自动备份还会在应用私有目录留一份，数据自检发现异常时可一键回滚。': 'Off by default. When enabled, it checks the interval only on launch or resume, never in the background. The folder is granted through the system picker, and you choose how many copies to keep. A private snapshot of the latest backup enables one-tap rollback if the integrity check fails.',
    '提醒通知不弹出？': 'Notifications do not appear?',
    '请确认系统通知权限已开启，并在电池设置里允许后台运行。部分 ROM 的省电策略会延迟本地通知，本 App 不联网、不常驻后台。': 'Make sure notifications are allowed and background running is permitted in battery settings. Some ROMs delay local notifications; this app has no network access and does not run in the background.',
    '数据会上传吗？': 'Is my data uploaded?',
    '不会。所有任务、打卡、标签和设置都只保存在本机 SQLite，没有账号、没有网络请求。': 'No. Tasks, check-ins, tags, and settings stay in the local SQLite database. There is no account and no network request.',
    '小米 / Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。': 'Xiaomi / Redmi: Settings → Apps → 循记打卡 → Battery saver → No restrictions, and allow auto-start.',
    '华为 / 荣耀：设置 → 电池 → 应用启动管理 → 循记打卡 → 手动管理，允许自启动。': 'Huawei / Honor: Settings → Battery → App launch → 循记打卡 → Manage manually, allow auto-start.',
    'OPPO / realme：设置 → 电池 → 应用耗电管理 → 循记打卡 → 允许后台运行。': 'OPPO / realme: Settings → Battery → App battery management → 循记打卡 → Allow background activity.',
    'vivo / iQOO：设置 → 电池 → 后台耗电管理 → 循记打卡 → 允许后台高耗电。': 'vivo / iQOO: Settings → Battery → Background power management → 循记打卡 → Allow high background power use.',
    '一加：设置 → 电池 → 电池优化 → 循记打卡 → 不优化，并允许自启动。': 'OnePlus: Settings → Battery → Battery optimization → 循记打卡 → Don\'t optimize, and allow auto-start.',
    '魅族：设置 → 电量管理 → 后台管理 → 循记打卡 → 允许后台运行。': 'Meizu: Settings → Power management → Background management → 循记打卡 → Allow background running.',
    '三星：设置 → 电池 → 后台使用限制 → 循记打卡 → 从“休眠应用”中移除。': 'Samsung: Settings → Battery → Background usage limits → 循记打卡 → Remove from sleeping apps.',
    '在系统电池设置中允许「循记打卡」后台运行，避免零点刷新被清理。': 'Allow 循记打卡 to run in the background in system battery settings so the midnight refresh is not killed.',
  },
  'ja': {
    '为什么第二天打卡状态会重置？': '翌日になるとチェック状態がリセットされるのはなぜ？',
    '打卡记录按「任务 + 日期」保存。每日任务在每一天都是新的记录，所以零点后自动回到未完成状态，不需要改写数据库。': 'チェック記録は「タスク＋日付」単位で保存されます。毎日のタスクは日ごとに新しい記録になるため、0時以降は未完了に戻ります。データベースを書き換える必要はありません。',
    '临时待办完成后为什么不见了？': '一時的なToDoは完了後にどこへ？',
    '临时待办是一次性任务。勾选完成后会从今日列表消失，但完成当天仍会计入热力图；可在任务详情里撤销或查看。': '一時的なToDoは1回限りのタスクです。完了すると今日の一覧から消えますが、当日のヒートマップには集計されます。詳細から元に戻したり確認できます。',
    '桌面小组件不刷新怎么办？': 'ホーム画面ウィジェットが更新されない',
    '先在小组件配置页点「立即刷新」。国产 ROM 可能限制后台，请在设置 → 保活帮助里允许后台运行和自启动；零点刷新使用系统非精确闹钟，可能会有几分钟延迟。': 'ウィジェット設定の「今すぐ更新」を押してください。中国系ROMはバックグラウンドを制限することがあるため、設定→常駐サポートでバックグラウンド実行と自動起動を許可してください。0時の更新は非正確アラームのため数分遅れる場合があります。',
    '备份文件在哪里？会申请存储权限吗？': 'バックアップはどこ？ストレージ権限は必要？',
    '导出时由系统文件选择器决定保存位置，App 只写入你选中的文件，不会申请存储权限。导入会先校验，再让你选择覆盖或追加。': '保存先はシステムのファイル選択画面で決まります。アプリは選んだファイルだけに書き込み、ストレージ権限は要求しません。インポートは検証後に上書きか追加を選べます。',
    '自动备份什么时候执行？': '自動バックアップはいつ実行？',
    '默认关闭。开启后只在 App 启动或回到前台时检查周期，不会常驻后台；目录由系统文件选择器授权，保留份数可自选。最近一次自动备份还会在应用私有目录留一份，数据自检发现异常时可一键回滚。': '初期設定はオフです。有効にすると起動時または復帰時にのみ周期を確認し、常駐しません。保存先はシステム選択画面で許可し、保持数を選べます。最新の自動バックアップはアプリ専用領域にも保存され、整合性検査で異常が見つかった場合にワンタップで戻せます。',
    '提醒通知不弹出？': 'リマインダー通知が出ない',
    '请确认系统通知权限已开启，并在电池设置里允许后台运行。部分 ROM 的省电策略会延迟本地通知，本 App 不联网、不常驻后台。': '通知権限とバッテリー設定のバックグラウンド実行を確認してください。一部ROMの省電力設定はローカル通知を遅延させます。本アプリは通信せず、常駐もしません。',
    '数据会上传吗？': 'データは送信されますか？',
    '不会。所有任务、打卡、标签和设置都只保存在本机 SQLite，没有账号、没有网络请求。':
        'いいえ。タスク、チェック記録、タグ、設定はすべて端末内のSQLiteにのみ保存されます。アカウントも通信もありません。',
    '小米 / Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。':
        'Xiaomi / Redmi：設定 → アプリ → 循记打卡 → 省電力 → 制限なし、自動起動を許可。',
    '华为 / 荣耀：设置 → 电池 → 应用启动管理 → 循记打卡 → 手动管理，允许自启动。':
        'Huawei / Honor：設定 → バッテリー → アプリ起動管理 → 循记打卡 → 手動管理、自動起動を許可。',
    'OPPO / realme：设置 → 电池 → 应用耗电管理 → 循记打卡 → 允许后台运行。':
        'OPPO / realme：設定 → バッテリー → アプリ電力管理 → 循记打卡 → バックグラウンド実行を許可。',
    'vivo / iQOO：设置 → 电池 → 后台耗电管理 → 循记打卡 → 允许后台高耗电。':
        'vivo / iQOO：設定 → バッテリー → バックグラウンド電力管理 → 循记打卡 → 高いバックグラウンド消費を許可。',
    '一加：设置 → 电池 → 电池优化 → 循记打卡 → 不优化，并允许自启动。':
        'OnePlus：設定 → バッテリー → バッテリー最適化 → 循记打卡 → 最適化しない、自動起動を許可。',
    '魅族：设置 → 电量管理 → 后台管理 → 循记打卡 → 允许后台运行。':
        'Meizu：設定 → 電力管理 → バックグラウンド管理 → 循记打卡 → バックグラウンド実行を許可。',
    '三星：设置 → 电池 → 后台使用限制 → 循记打卡 → 从“休眠应用”中移除。':
        'Samsung：設定 → バッテリー → バックグラウンド使用制限 → 循记打卡 → 「スリープアプリ」から削除。',
    '在系统电池设置中允许「循记打卡」后台运行，避免零点刷新被清理。':
        'システムのバッテリー設定で「循记打卡」のバックグラウンド実行を許可し、0時の更新が停止されないようにしてください。',
  },
  'fr': {
    '为什么第二天打卡状态会重置？':
        'Pourquoi les cases se réinitialisent-elles le lendemain ?',
    '打卡记录按「任务 + 日期」保存。每日任务在每一天都是新的记录，所以零点后自动回到未完成状态，不需要改写数据库。': 'Les pointages sont enregistrés par tâche et par date. Une tâche quotidienne obtient un nouvel enregistrement chaque jour ; elle repasse donc à zéro à minuit sans réécrire la base.',
    '临时待办完成后为什么不见了？':
        'Pourquoi une tâche ponctuelle disparaît-elle après validation ?',
    '临时待办是一次性任务。勾选完成后会从今日列表消失，但完成当天仍会计入热力图；可在任务详情里撤销或查看。': 'Une tâche ponctuelle ne sert qu\'une fois. Une fois cochée, elle quitte la liste du jour mais compte encore pour la carte de chaleur ; vous pouvez l\'annuler ou la consulter dans les détails.',
    '桌面小组件不刷新怎么办？': 'Le widget ne se rafraîchit pas ?',
    '先在小组件配置页点「立即刷新」。国产 ROM 可能限制后台，请在设置 → 保活帮助里允许后台运行和自启动；零点刷新使用系统非精确闹钟，可能会有几分钟延迟。': 'Appuyez d\'abord sur « Rafraîchir » dans les réglages du widget. Certains ROM chinois limitent l\'arrière-plan : autorisez l\'exécution en arrière-plan et le démarrage automatique dans Réglages → Maintien. Le rafraîchissement de minuit utilise une alarme imprécise et peut avoir quelques minutes de retard.',
    '备份文件在哪里？会申请存储权限吗？':
        'Où est la sauvegarde ? Faut-il un accès au stockage ?',
    '导出时由系统文件选择器决定保存位置，App 只写入你选中的文件，不会申请存储权限。导入会先校验，再让你选择覆盖或追加。': 'Le sélecteur système choisit l\'emplacement. L\'application n\'écrit que le fichier choisi et ne demande aucune permission de stockage. L\'import valide d\'abord, puis propose d\'écraser ou d\'ajouter.',
    '自动备份什么时候执行？': 'Quand la sauvegarde automatique s\'exécute-t-elle ?',
    '默认关闭。开启后只在 App 启动或回到前台时检查周期，不会常驻后台；目录由系统文件选择器授权，保留份数可自选。最近一次自动备份还会在应用私有目录留一份，数据自检发现异常时可一键回滚。': 'Désactivée par défaut. Une fois activée, elle vérifie la période uniquement au lancement ou au retour au premier plan, sans rester en arrière-plan. Le dossier est autorisé par le sélecteur système et vous choisissez le nombre de copies. Un instantané privé de la dernière sauvegarde permet une restauration en un geste si le contrôle d\'intégrité échoue.',
    '提醒通知不弹出？': 'Les rappels ne s\'affichent pas ?',
    '请确认系统通知权限已开启，并在电池设置里允许后台运行。部分 ROM 的省电策略会延迟本地通知，本 App 不联网、不常驻后台。': 'Vérifiez que les notifications sont autorisées et que l\'exécution en arrière-plan est permise. Certains ROM retardent les notifications locales ; cette application n\'a aucun accès réseau et ne reste pas en arrière-plan.',
    '数据会上传吗？': 'Mes données sont-elles envoyées ?',
    '不会。所有任务、打卡、标签和设置都只保存在本机 SQLite，没有账号、没有网络请求。': 'Non. Tâches, pointages, tags et réglages restent dans la base SQLite locale. Aucun compte, aucune requête réseau.',
    '小米 / Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。': 'Xiaomi / Redmi : Réglages → Applications → 循记打卡 → Économiseur → Sans restriction, et autoriser le démarrage auto.',
    '华为 / 荣耀：设置 → 电池 → 应用启动管理 → 循记打卡 → 手动管理，允许自启动。': 'Huawei / Honor : Réglages → Batterie → Lancement des applis → 循记打卡 → Gestion manuelle, autoriser le démarrage auto.',
    'OPPO / realme：设置 → 电池 → 应用耗电管理 → 循记打卡 → 允许后台运行。': 'OPPO / realme : Réglages → Batterie → Gestion de l\'énergie → 循记打卡 → Autoriser l\'activité en arrière-plan.',
    'vivo / iQOO：设置 → 电池 → 后台耗电管理 → 循记打卡 → 允许后台高耗电。': 'vivo / iQOO : Réglages → Batterie → Gestion arrière-plan → 循记打卡 → Autoriser une forte consommation en arrière-plan.',
    '一加：设置 → 电池 → 电池优化 → 循记打卡 → 不优化，并允许自启动。': 'OnePlus : Réglages → Batterie → Optimisation → 循记打卡 → Ne pas optimiser, et autoriser le démarrage auto.',
    '魅族：设置 → 电量管理 → 后台管理 → 循记打卡 → 允许后台运行。': 'Meizu : Réglages → Gestion de l\'énergie → Gestion arrière-plan → 循记打卡 → Autoriser l\'exécution en arrière-plan.',
    '三星：设置 → 电池 → 后台使用限制 → 循记打卡 → 从“休眠应用”中移除。': 'Samsung : Réglages → Batterie → Limites d\'usage → 循记打卡 → Retirer des applis en veille.',
    '在系统电池设置中允许「循记打卡」后台运行，避免零点刷新被清理。': 'Autorisez 循记打卡 à fonctionner en arrière-plan dans les réglages de batterie pour éviter que le rafraîchissement de minuit soit interrompu.',
  },
  'es': {
    '为什么第二天打卡状态会重置？': '¿Por qué se reinicia el estado al día siguiente?',
    '打卡记录按「任务 + 日期」保存。每日任务在每一天都是新的记录，所以零点后自动回到未完成状态，不需要改写数据库。': 'Los registros se guardan por tarea y fecha. Una tarea diaria obtiene un registro nuevo cada día, así que a medianoche vuelve a estar sin marcar sin reescribir la base de datos.',
    '临时待办完成后为什么不见了？': '¿Por qué desaparece una tarea puntual al completarla?',
    '临时待办是一次性任务。勾选完成后会从今日列表消失，但完成当天仍会计入热力图；可在任务详情里撤销或查看。': 'Una tarea puntual es de un solo uso. Al marcarla sale de la lista de hoy, pero sigue contando para el mapa de calor del día; puedes deshacerla o verla en los detalles.',
    '桌面小组件不刷新怎么办？': '¿El widget no se actualiza?',
    '先在小组件配置页点「立即刷新」。国产 ROM 可能限制后台，请在设置 → 保活帮助里允许后台运行和自启动；零点刷新使用系统非精确闹钟，可能会有几分钟延迟。': 'Pulsa «Actualizar ahora» en los ajustes del widget. Algunas ROM chinas limitan el segundo plano: permite la ejecución en segundo plano y el inicio automático en Ajustes → Mantener activo. La actualización de medianoche usa una alarma inexacta y puede retrasarse unos minutos.',
    '备份文件在哪里？会申请存储权限吗？':
        '¿Dónde está la copia? ¿Pide permiso de almacenamiento?',
    '导出时由系统文件选择器决定保存位置，App 只写入你选中的文件，不会申请存储权限。导入会先校验，再让你选择覆盖或追加。': 'El selector del sistema elige la ubicación. La app solo escribe el archivo seleccionado y no pide permisos de almacenamiento. La importación valida primero y luego permite sobrescribir o añadir.',
    '自动备份什么时候执行？': '¿Cuándo se ejecuta la copia automática?',
    '默认关闭。开启后只在 App 启动或回到前台时检查周期，不会常驻后台；目录由系统文件选择器授权，保留份数可自选。最近一次自动备份还会在应用私有目录留一份，数据自检发现异常时可一键回滚。': 'Desactivada por defecto. Al activarla, solo comprueba el intervalo al iniciar o volver al primer plano, nunca en segundo plano. La carpeta se autoriza con el selector del sistema y eliges cuántas copias conservar. Una instantánea privada de la última copia permite revertir con un toque si falla la comprobación de integridad.',
    '提醒通知不弹出？': '¿No aparecen los recordatorios?',
    '请确认系统通知权限已开启，并在电池设置里允许后台运行。部分 ROM 的省电策略会延迟本地通知，本 App 不联网、不常驻后台。': 'Comprueba que las notificaciones están permitidas y que el segundo plano está autorizado en la batería. Algunas ROM retrasan las notificaciones locales; esta app no usa red ni se queda en segundo plano.',
    '数据会上传吗？': '¿Se suben mis datos?',
    '不会。所有任务、打卡、标签和设置都只保存在本机 SQLite，没有账号、没有网络请求。': 'No. Tareas, registros, etiquetas y ajustes permanecen en la base SQLite local. No hay cuenta ni peticiones de red.',
    '小米 / Redmi：设置 → 应用设置 → 循记打卡 → 省电策略 → 无限制，并允许自启动。': 'Xiaomi / Redmi: Ajustes → Aplicaciones → 循记打卡 → Ahorro de batería → Sin restricciones, y permitir inicio automático.',
    '华为 / 荣耀：设置 → 电池 → 应用启动管理 → 循记打卡 → 手动管理，允许自启动。': 'Huawei / Honor: Ajustes → Batería → Inicio de apps → 循记打卡 → Gestión manual, permitir inicio automático.',
    'OPPO / realme：设置 → 电池 → 应用耗电管理 → 循记打卡 → 允许后台运行。': 'OPPO / realme: Ajustes → Batería → Gestión de energía → 循记打卡 → Permitir actividad en segundo plano.',
    'vivo / iQOO：设置 → 电池 → 后台耗电管理 → 循记打卡 → 允许后台高耗电。': 'vivo / iQOO: Ajustes → Batería → Gestión de segundo plano → 循记打卡 → Permitir alto consumo en segundo plano.',
    '一加：设置 → 电池 → 电池优化 → 循记打卡 → 不优化，并允许自启动。': 'OnePlus: Ajustes → Batería → Optimización → 循记打卡 → No optimizar, y permitir inicio automático.',
    '魅族：设置 → 电量管理 → 后台管理 → 循记打卡 → 允许后台运行。': 'Meizu: Ajustes → Gestión de energía → Gestión de segundo plano → 循记打卡 → Permitir ejecución en segundo plano.',
    '三星：设置 → 电池 → 后台使用限制 → 循记打卡 → 从“休眠应用”中移除。': 'Samsung: Ajustes → Batería → Límites de uso → 循记打卡 → Quitar de apps en reposo.',
    '在系统电池设置中允许「循记打卡」后台运行，避免零点刷新被清理。': 'Permite que 循记打卡 se ejecute en segundo plano en los ajustes de batería para que la actualización de medianoche no se interrumpa.',
  },
};
