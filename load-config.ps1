# ___________________  Константы ______________________
$configFile     = "config.json" # Путь к файлу конфигурации
$backupDir      = "backups"     # Папка для бэкапов конфигураций, каждый раз создается новый файл конфигурации
$currentDir     = "current"     # Папка для Складирования конфигураций поверх старых


# ___________________  Переменные  ______________________
$config = Get-Content -Path $configFile | ConvertFrom-Json
$Routers = $config.Routers




# ___________________  Проверки  ______________________
# модуль Posh-SSH установлен
#if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
#    Install-Module Posh-SSH -Force
#}
#Import-Module Posh-SSH

# Папка для бэкапов существует
if (-not (Test-Path $backupDir -PathType Container)) {
    New-Item -Path $backupDir -ItemType Directory > $null
    Write-host "Создана папка $backupDir"
}
# Папка для текущих конфигураций существует
if (-not (Test-Path $currentDir -PathType Container)) {
    New-Item -Path $currentDir -ItemType Directory > $null
    Write-host "Создана папка $currentDir"
}






# ___________________  Основной код  ______________________

foreach ($router in $Routers) {
    $ip = $router.IP
    $user = $router.User
    $pass = $router.Password
    $label = $router.Label

    Write-Host
    Write-Host "Подключение к $ip" -ForegroundColor Cyan

    $secpass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($user, $secpass)

    # Проверка доступности роутера
    $ping = Test-Connection -ComputerName $ip -Count 1 -ErrorAction SilentlyContinue
    if ($ping.Status -ne "Success") {
        Write-Host "Ping не прошел роутер $label ( $ip  )" -ForegroundColor Yellow
    } else {
        Write-Host "Ping Success до роутера $label ( $ip  )"
    }


    try {
        # Устанавливаем SSH-сессию
        $session = New-SSHSession -ComputerName $ip -Credential $cred -AcceptKey -ErrorAction Stop
        # Получаем конфиг
        $result = Invoke-SSHCommand -SessionId $session.SessionId -Command "/export compact" -ErrorAction Stop
    } catch {
        Write-Host "Ошибка при проверке SSH на роутере $label ( $ip  )" -ForegroundColor Red
        Write-Host "Пропускаем" -ForegroundColor DarkGray
        continue
    }

    if ($null -eq $result) {
        Write-Host "Ошибка при получении конфигурации с роутера $label ( $ip ), полученная конфигурация пустая" -ForegroundColor Red
        Write-Host "Пропускаем" -ForegroundColor DarkGray
        continue
    }


    
    # Сохраняем вывод в файл
    $date = Get-Date -Format "yyyy-MM-dd_HH-mm"
    $backupFilePath = "$backupDir\$label-$date.conf"
    $currentFilePath = "$currentDir\$label.conf"
    try {
        $result.Output | Out-File -Encoding utf8 $backupFilePath
        $result.Output | Out-File -Encoding utf8 $currentFilePath -Force
    } catch {
        Write-Host "Ошибка при сохранении конфигурации с роутера $label ( $ip )" -ForegroundColor Red
        <#Do this if a terminating exception happens#>
    }



    # Закрываем сессию
    Remove-SSHSession -SessionId $session.SessionId
}
