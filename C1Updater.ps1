Param(
        $TargetBase,                            # имя целевой базы для обновления
        $TargetBaseServer,                      # имя сервера целевой базы для обновления
        $TargetBasePort,                        # порт сервера целевой базы, если отличается от стандартного то 1541
        $TargetBaseAgentPort,                   # порт агента сервера целевой базы, если отличается от стандартного то 1540
        $PermissionCode,                        # код разрешения доступа, если не указан, то устанавливается произвольный
        $ApplyCFPath,                           # путь к применяемому файлу конфигурации, если отсутствует, то просто применяем конфигурацию
        $WorkloadBeforeUpdatePath,              # имя обработки, выполняемой перед обновлением конфигурации. Если файла нет, пропускаем этап
        $WorkloadAfterUpdatePath,               # имя обработки, выполняемой перед обновлением конфигурации. Если файла нет, пропускаем этап
        $BaseUser,                              # имя пользователя для подключения к базе
        $BaseUserPass,                          # пароль пользователя для подключения к базе
        $ConfigurationRepositoryF,              # адрес хранилища конфигурации
        $ConfigurationRepositoryN,              # имя пользователя хранилища конфигурации
        $ConfigurationRepositoryP,              # пароль пользователя хранилища конфигурации
        $Extension,                             # имя расширения хранилища конфигурации
        $ConfigurationRepositoryExtension,      # для совместимости        
        $UpdateByClientInTheEnd,                # /C ЗапуститьОбновлениеИнформационнойБазы
        $UseRAServer,                           # Использовать не ком-соединение, а rac
        $LockMessage,                           # Сообщение, используемое для блокировки базы 1С
        $C1Files                                # Каталог для используемой версии 1С
    )

function detect_1c{
    try{
        $temp                                   =   New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT
        $CLSID                                  =   (Get-ItemProperty -Path "HKCR:\V83.COMConnector\CLSID")."(default)"
        if (Test-Path -Path "HKCR:\Wow6432Node\CLSID\$CLSID\InprocServer32"){
            $ComCntr                            =   (Get-ItemProperty -Path "HKCR:\Wow6432Node\CLSID\$CLSID\InprocServer32")."(default)"
        }
        if (Test-Path -Path "HKCR:\CLSID\$CLSID\InprocServer32"){
            $ComCntr                            =   (Get-ItemProperty -Path "HKCR:\CLSID\$CLSID\InprocServer32")."(default)"
        }
        $c1_way                                 =   $ComCntr -replace "comcntr.dll","1cv8.exe"
        Remove-PSDrive -Name HKCR
        if(Test-Path $c1_way){
            return ("`"$c1_way`"")
        }else{
            log_w "Я не смог найти исполняемый файл 1С"
            Exit 1
        }
    }catch {
        log_w "Всё плохо: `r`n $_"
        Exit 2
    }
}
function run_me {
    Param($run_exe,$run_args,$log_text,$log_file)
    try{
        log_w $log_text
        $exit_code,$output                      =   Invoke-Process -FilePath $run_exe -ArgumentList $run_args -ErrorAction SilentlyContinue
        if(Test-Path -Path $log_file){
            $c1_log                             =   Get-Content $log_file
            if($c1_log){
                log_w "А вот что рассказал мне 1С:`r`n $c1_log"
            }else{
                log_w "1С ничего не сообщил по итогам предыдущей команды"
            }
        }
        if($exit_code -ne 0){
            log_w "Что то пошло не так, и это прискорбно. $output"
            Exit 3
        }
    }
    catch{
        log_w "Мне очень жаль, но я не смог. И вот почему: `r`n$_"        
        Exit 4
    }
}
function Invoke-Process {
    param
    (
        [string]$FilePath,
        [string]$ArgumentList
    )   
    try {
        $stdOutTempFile                         =   [System.IO.Path]::GetTempFileName()
        $stdErrTempFile                         =   [System.IO.Path]::GetTempFileName()
        $startProcessParams                     =   @{
            FilePath                            =   $FilePath
            ArgumentList                        =   $ArgumentList
            RedirectStandardError               =   $stdErrTempFile
            RedirectStandardOutput              =   $stdOutTempFile
            Wait                                =   $true;
            PassThru                            =   $true;
            NoNewWindow                         =   $true;
        }
        $cmd                                    =   Start-Process @startProcessParams
        $cmdOutput                              =   Get-Content -Path $stdOutTempFile -Raw
        $cmdError                               =   Get-Content -Path $stdErrTempFile -Raw
        if ($cmd.ExitCode -ne 0) {
            return $cmd.ExitCode,$cmdError
        }else{
            return $cmd.ExitCode,$cmdOutput
        }
    } catch {
        return "Got Error $_"
    } finally {
        Remove-Item -Path $stdOutTempFile, $stdErrTempFile -Force -ErrorAction SilentlyContinue
    }
}
function log_w{
    Param($msg)
    $CurDate                                    =   (get-date -UFormat "%Y.%m.%d %H.%M.%S").ToString()    
    $log                                        =   (split-path $MyInvocation.PSCommandPath -Leaf)
    $log                                        =   "$log.log"
    $l_msg                                      =   "$CurDate `:`:`: $msg"    
    $l_msg  | Out-File -FilePath $log -Append
    Write-Host $l_msg
}
function check4param {
    param (
        $ParamValue,
        $ParamName
    )
    if(!$ParamValue){
        log_w "Не указан параметр $ParamName"
        Exit 5
    }
}
function chk4fileParam{
    param (
        $ParamValue,
        $ParamName
    )
    $ParamValue                                 =   $ParamValue -replace "[""]+","" -replace """",""
    if($ParamValue){
        if (!(Test-Path $ParamValue)){
            log_w "Некорректный параметр $ParamName со значением $ParamValue"
            Exit 6
        }
    }
    return $true
}
function enableUnsafeActions{
    param (
        $conf_filename
    )
    log_w "Разрешаю выполнение внешних обработок в $conf_filename"
    $conf                                       =   Get-Content -path $conf_filename    
    $conf_filename_backup                       =   $conf_filename+".backup"
    $enable_4_base                              =   "`r`nDisableUnsafeActionProtection=$TargetBase"
    if(($conf -match $enable_4_base) -eq $false){
        Copy-Item   -Path $conf_filename -Destination $conf_filename_backup
        if(Get-item -Path $conf_filename_backup){
            $TextBytes                          =   [Text.Encoding]::GetEncoding("UTF-8").GetBytes($enable_4_base)
            $fs                                 =   New-Object IO.FileStream($conf_filename,[IO.FileMode]::Open,[Security.AccessControl.FileSystemRights]::AppendData,[IO.FileShare]::Read,8,[IO.FileOptions]::None)
            $fs.Write($TextBytes,0,$TextBytes.Count)
            $fs.Close()
            return $true
        }
    }    
    return $false
}
function disableUnsafeActions{
    param (
        $conf_filename
    )
    try {
        log_w "Возвращаю $conf_filename"
        $conf                                   =   Get-Content -path $conf_filename    
        $conf_filename_backup                   =   $conf_filename+".backup"
        if(Get-Item $conf_filename_backup){
            Remove-Item $conf_filename
            Move-Item $conf_filename_backup $conf_filename
        }        
    }catch [System.Exception]{
        log_w "Got Exception on disabling unsafe actions `r`n$_"
    }    
}
function GetInfoBase{
    param(
        $BBBase,
        $BBServer,
        $BBAgentPort,
        $BBBaseUser,
        $BBBasePass
    )
    try{
        $gib_ret                                =   [System.Collections.ArrayList]@()
        $BBConnectionString                     =   "$BBServer`:$BBAgentPort"
        if(!($Global:Agent)){
            $Global:Agent                       =   $global:COM.ConnectAgent($BBConnectionString)
            $Global:Cluster                     =   $Global:Agent.GetClusters()
            $Global:firstcluster                =   $Global:Cluster.GetValue(0)                        # это конечно надо переделалать на несколько кластеров
            $Global:Agent.Authenticate($firstcluster,"","")         
        } 
        $WorkingProcesses                       =   $Global:Agent.GetWorkingProcesses($Global:firstcluster)
        foreach($WorkingProcess in $WorkingProcesses){
            $WP_HostName                        =   $WorkingProcess.HostName
            $WP_MainPort                        =   $WorkingProcess.MainPort
            $WPConnection                       =   $global:COM.ConnectWorkingProcess("$WP_HostName`:$WP_MainPort")
            $WPConnection.AddAuthentication($BBBaseUser, $BBBasePass)
            $BaseList                           =   $WPConnection.GetInfoBases()            
            foreach($Base in $BaseList){
                if($Base.Name -eq $BBBase){
                    #$gib_ret.Add($Base)
                    return $WPConnection,$Base
                }
            }            
        }    
    }catch [System.Exception]{
        log_w "Got Exception on GetInfoBase `r`n$_"
        Exit 7
    }    
}
function GetScheduledJobsDeniedState{
    param(
        $BBBase,
        $BBServer,
        $BBAgentPort,
        $BBpermissionCode,
        $BBBaseUser,
        $BBBasePass
    )
    if($global:UseRAServer){
        #get sheduled jobs status
        $srv_ib                                 =   racGetInfobaseGUID  -rgig_srv       $global:UseRAServer `
                                                                        -rgig_ib_name   $BBBase `
                                                                        -rgig_user_name $BBBaseUser `
                                                                        -rgig_user_pass $BBBasePass
        $c_infb_info                            =   "infobase info $srv_ib"
        try {    
            $gsjds_ret                          =   (Invoke-Process -FilePath $global:rac -ArgumentList $c_infb_info)
            $sch_j_locks                        =   ($gsjds_ret[1] | Select-String -Pattern $global:rx_infb_sch_j)
            $sch_j_lock                         =   $sch_j_locks.Matches[0].Groups[1].Value
            log_w "Scheduled jobs lock state is $sch_j_lock"
            return $sch_j_lock
        } catch {
            log_w "get scheduled jobs lock state error $_"
            exit(1)
        }        
    }else {
        try{
            $gsjds_base                         =   (GetInfoBase    -BBBase             $BBBase `
                                                                    -BBpermissionCode   $BBpermissionCode  `
                                                                    -BBServer           $BBServer `
                                                                    -BBAgentPort        $BBAgentPort `
                                                                    -BBBaseUser         $BBBaseUser `
                                                                    -BBBasePass         $BBBasePass)[1]
            $state                              =   $gsjds_base.ScheduledJobsDenied                                                                    
            log_w "Scheduled jobs lock state is $state"
            return $state
        }catch [System.Exception]{
            log_w "Got Exception while getting job state `r`n$_"
            Exit 8
        }
    }
}
function LockBaseByRac {
    param (
        $BBBase,
        $BBServer,
        $BBpermissionCode,
        $BBBaseUser,
        $BBBasePass
    )
    $srv_ib                                 =   racGetInfobaseGUID  -rgig_srv       $BBServer `
                                                                    -rgig_ib_name   $BBBase `
                                                                    -rgig_user_name $BBBaseUser `
                                                                    -rgig_user_pass $BBBasePass
    $c_infb_lock                            =   "infobase update `
                                                --denied-from `""+($global:lockfrom -replace "T"," ")+"`" `
                                                --denied-to   `""+($global:lockto   -replace "T"," ")+"`" `
                                                --denied-message ""$global:lockmessage""`
                                                --permission-code  $BBpermissionCode`
                                                --sessions-deny=on `
                                                --scheduled-jobs-deny=on`
                                                $srv_ib" `
                                                -replace "\s{2,}"," "
    $lbbr_ret                               =   Invoke-Process $Global:rac $c_infb_lock
    log_w "Блокировка базы завершена: $lbbr_ret"
    return $lbbr_ret
}
function UnLockBaseByRac {
    param (
        $BBBase,
        $BBServer,
        $BBpermissionCode,
        $BBBaseUser,
        $BBBasePass,
        $BBUnlockJobs
    )
    $srv_ib                                 =   racGetInfobaseGUID  -rgig_srv       $BBServer `
                                                                    -rgig_ib_name   $BBBase `
                                                                    -rgig_user_name $BBBaseUser `
                                                                    -rgig_user_pass $BBBasePass
    $c_infb_ulock                           =   "infobase update `
                                                --sessions-deny=off`
                                                --scheduled-jobs-deny=$BBUnlockJobs `
                                                $srv_ib" `
                                                -replace "\s{2,}"," "                                                                    
    $ulbbr_ret                              =   Invoke-Process $Global:rac $c_infb_ulock
    log_w "База успешно разблокирована. Блокировка регламентных заданий = $BBUnlockJobs"
    return $ulbbr_ret
}
function LockBase{    
    param(
        $BBBase,
        $BBServer,
        $BBAgentPort,
        $BBpermissionCode,
        $BBBaseUser,
        $BBBasePass
    )
    if($global:UseRAServer){
        LockBaseByRac                           -BBBase             $BBBase `
                                                -BBpermissionCode   $BBpermissionCode  `
                                                -BBServer           $global:UseRAServer `
                                                -BBBaseUser         $BBBaseUser `
                                                -BBBasePass         $BBBasePass
        log_w "Заблокировал базу при помощи RAC/RAS. Код скажу только тебе, он = $BBpermissionCode"
        return $true
    }
    try{
        if(!$Global:magic){
            $Global:magic                       =   (GetInfoBase    -BBBase             $BBBase `
                                                                    -BBpermissionCode   $BBpermissionCode  `
                                                                    -BBServer           $BBServer `
                                                                    -BBAgentPort        $BBAgentPort `
                                                                    -BBBaseUser         $BBBaseUser `
                                                                    -BBBasePass         $BBBasePass)
            $Global:WPConnection                =   $Global:magic[0]
            $Global:Base                        =   $Global:magic[1]
        }
        #foreach($Base in $BaseList){
            log_w "Я нашёл нужную базу! $BBBase. Пробую попасть внутрь."
            if($BBBaseUser){
                log_w "Оказывается, я $BBBaseUser. И у меня получилось войти в базу."
            }else{
                log_w "Пусть я и остался анонимен, но в базу вошёл. Потому что там вообще нет пользователей!"
            }
            $Global:Base.DeniedFrom             =   $global:lockfrom
            $Global:Base.DeniedTo               =   $global:lockto
            $Global:Base.DeniedMessage          =   $global:LockMessage
            $Global:Base.SessionsDenied         =   $true
            $Global:Base.ScheduledJobsDenied    =   $true
            $Global:Base.PermissionCode         =   $BBpermissionCode
            $Global:WPConnection.UpdateInfoBase($Global:Base)
            log_w "Пока я работаю, в базе больше не будет работать никто. Я всех заблокировал. И фоновые задания тоже. Код скажу только тебе, он = $BBpermissionCode"
            return $true
        #}
        return false
    }catch [System.Exception]{
        log_w "Got Exception while locking base `r`n$_"
        Exit 9
    }
}
function UnlockBase{
    param(
        $BBBase,
        $BBServer,
        $BBAgentPort,
        $BBpermissionCode,
        $BBBaseUser,
        $BBBasePass,
        $BBUnlockJobs
    )
    try{          
        if($global:UseRAServer){
            UnLockBaseByRac                         -BBBase             $BBBase `
                                                    -BBpermissionCode   $BBpermissionCode  `
                                                    -BBServer           $global:UseRAServer `
                                                    -BBBaseUser         $BBBaseUser `
                                                    -BBBasePass         $BBBasePass `
                                                    -BBUnlockJobs       $BBUnlockJobs
            log_w "Разблокировал базу с помощью RAC/RAS"
            return $true
        }              
        if(!$Global:magic){
            $Global:magic                       =   (GetInfoBase    -BBBase             $BBBase `
                                                                    -BBpermissionCode   $BBpermissionCode  `
                                                                    -BBServer           $BBServer `
                                                                    -BBAgentPort        $BBAgentPort `
                                                                    -BBBaseUser         $BBBaseUser `
                                                                    -BBBasePass         $BBBasePass)
            $Global:WPConnection                =   $Global:magic[0]
            $Global:Base                        =   $Global:magic[1]
        }
        #foreach($Base in $BaseList){
            try{
                $Global:Base.DeniedMessage      =   ""
                $Global:Base.SessionsDenied     =   $false
                $Global:Base.ScheduledJobsDenied=   $BBUnlockJobs
                $Global:WPConnection.UpdateInfoBase($Global:Base)
                return $true
            } catch [System.Exception]{
                log_w "Got Exception on SessionsDenied`r`n$_"
            }
        #}
        return $false
    }catch [System.Exception]{
        log_w "Got Exception on unlock `r`n$_"
        Exit 10
    }
}
function KillUsersByRac {
    param (
        $BBBase,
        $BBServer,
        $BBBaseUser,
        $BBBasePass
    )
    $reason                                 =   "--error-message ""$global:lock_message"""
    $srv                                    =   racGetClusterGUID   -rgs_srv        $BBServer
    $srv_ib                                 =   racGetInfobaseGUID  -rgig_srv       $BBServer `
                                                                    -rgig_ib_name   $BBBase `
                                                                    -rgig_user_name $BBBaseUser `
                                                                    -rgig_user_pass $BBBasePass
    #get session list
    $c_sesn_list                            =   "session list $srv_ib"
    try {
        $sesns                              =   Invoke-Process $global:rac $c_sesn_list
        ($sesns | Select-String -AllMatches -Pattern $global:rx_sesn_guid).Matches |
        ForEach-Object{
            if($_ -ne $null){
                $guid                       =   $_.Groups[1].Value
                write-host "killing session $guid"                
                Invoke-Process $global:rac "session terminate --session $guid $reason $srv"
            }else{
                write-host "guid is undefined while session termination"
            }
        }
    }catch {
        Write-Host "get session list error $_"
        exit(1)
    }
    #----------------------
    #get connection list
    $c_conn_list                            =   "connection list $srv_ib"
    try {
        $conns                              =   Invoke-Process $global:rac $c_conn_list
        ($conns | Select-String -AllMatches -Pattern $global:rx_sspr_guids).Matches |
        ForEach-Object{
            if($_ -ne $null){
                $conn_guid                  =   $_.Groups[1].Value
                $prcs_guid                  =   $_.Groups[2].Value
                write-host "disconnectiong connection $conn_guid in process $prcs_guid"
                Invoke-Process $global:rac "connection disconnect --connection $conn_guid --process $prcs_guid $srv"
            }else{
                write-host "guid is undefined while session termination"
            }
        }
    } catch {
        Write-Host "get sessions list error $_"
        exit(16)
    }
}
function KillSession{
    param(
        $BBBase,
        $BBConnectionString
    )
    if($global:UseRAServer){
        KillUsersByRac                          -BBBase             $BBBase `
                                                -BBServer           $global:UseRAServer `
                                                -BBBaseUser         $BBBaseUser `
                                                -BBBasePass         $BBBasePass
        log_w "Удалил из базы все сеансы и соединений"
        return $true
    }    
    try{        
        if(!($Global:Agent)){
            $Global:Agent                       =   $global:COM.ConnectAgent($BBConnectionString)
            $Global:Cluster                     =   $Global:Agent.GetClusters()
            $Global:firstcluster                =   $Global:Cluster.GetValue(0)                        # это конечно надо переделалать на несколько кластеров
            $Global:Agent.Authenticate($firstcluster,"","")         
        }         
        $SessionList                            =   $Global:Agent.GetSessions($firstcluster)
        foreach($Session in $SessionList){
            if($Session.InfoBase.Name -eq $BBBase -and 
               $Session.AppID -ne "COMConsole" -and 
               $Session.AppID -ne "SrvrConsole"){            
               $Global:Agent.TerminateSession($Global:firstcluster, $Session)
            }
        }
        return $true
    }catch [System.Exception]{
        log_w "Got Exception while kill session `r`n$_"
        Exit 11
    }
}
function getDateString($cd,$t=$null){
    $dd                                     =   if(([string]$cd.Day).Length -gt 1){$cd.Day}else{"0"+$cd.Day} 
    $y                                      =   $cd.Year
    $m                                      =   if(([string]$cd.Month).Length -gt 1){$cd.Month}else{"0"+$cd.Month}
    $hr                                     =   if(([string]$cd.Hour).Length -gt 1){$cd.Hour}else{"0"+$cd.Month}
    $mnt                                    =   if(([string]$cd.Minute).Length -gt 1){$cd.Minute}else{"0"+$cd.Minute}
    $sec                                    =   if(([string]$cd.Second).Length -gt 1){$cd.Second}else{"0"+$cd.Second}
    if(!$t){
        $t                                  =   " "
    }
    return "$y-$m-$dd$t$hr`:$mnt`:$sec"
}
function racAuth ($r_user,$r_pass){    
    if($r_user){
        return $db_auth                     =   " --db-user ""$r_user"" --db-pwd ""$r_pass"""
    } else {
            return ""
    }
}
function racGetClusterGUID($rgs_srv){
    if($global:cluster_guid){
        return $global:cluster_guid
    }
    $c_clst_list                                =   "cluster list $rgs_srv"
    try {
        $rgcg_ret                               =   Invoke-Process ($global:rac) $c_clst_list
        $clusters                               =   ($rgcg_ret | Select-String -Pattern ($global:rx_guid))
        $cluster                                =   $clusters.Matches[0].Value
        log_w "rac working with $rgs_srv"
        $global:cluster_guid                    =   "--cluster $cluster $rgs_srv"
        return $global:cluster_guid
    } catch {
        log_w "get cluster guid error $_"
        exit(1)
    }
}
function racGetInfobaseGUID{
    param(
        $rgig_srv,
        $rgig_ib_name,
        $rgig_user_name,
        $rgig_user_pass
    )
    if($global:srv_ib){
        return $global:srv_ib
    }
    if($rgig_user_name){
        $db_auth                                =   "--db-user ""$rgig_user_name"" --db-pwd ""$rgig_user_pass"""
    } else {
        $db_auth                                =   ""
    }
    
    $srv                                        =   racGetClusterGUID $rgig_srv
    #get infobase guid
    $c_ifbs_list                                =   "infobase summary list $srv"
    try {
        $rgig_ret                               =   Invoke-Process $global:rac $c_ifbs_list
        $global:rx_ib_guid                      =   $global:rx_ib_guid_part+$rgig_ib_name
        $ib_guids                               =   ($rgig_ret | Select-String -Pattern $global:rx_ib_guid)
        $ib_guid                                =   $ib_guids.Matches[0].Groups[1].Value

        log_w "IB guid is $ib_guid"
        $global:srv_ib                          =   "--infobase $ib_guid $db_auth $srv"
        return $global:srv_ib
    } catch {
        log_w "get infobase guid error $_"
        exit(1)
    }
}

function main{
    chcp 1251
    chcp 65001
    log_w "================================================================================================"
    log_w "started by $env:USERDOMAIN\$env:USERNAME"
    # 1.1 Проверка обязательных параметров
    check4param $TargetBase                 '$TargetBase'
    check4param $TargetBaseServer           '$TargetBaseServer'
    
    # здесь - путь к 1С
    if(!$C1Files){
        $run1c                              =   detect_1c
        $rac                                =   $run1c -replace "1CV8.exe","rac.exe"
    }else{
        log_w "got $C1Files"
        $C1Files                            =   $C1Files -replace "[""]+",""
        $run1c                              =   "$C1Files\1CV8.exe"
        $rac                                =   "$C1Files\rac.exe"
    }
    $run1c                                  =   $run1c.replace("\\","\")
    $rac                                    =   $rac.replace("\\","\")
    $conf_cfg                               =   ($run1c -replace '"','' -replace "1CV8.EXE","conf\conf.cfg").replace("\\","\")
    if(!$UseRAServer){
        $global:COM                         =   New-Object -ComObject "V83.COMConnector"
        $global:lockfrom                    =   getDateString (get-date)
        $lockfrom                           =   $global:lockfrom
        $global:lockto                      =   getDateString (get-date).AddDays(1)
        $lockto                             =   $global:lockto
    }else{
        $global:lockfrom                    =   getDateString (get-date) "T"
        $lockfrom                           =   $global:lockfrom -replace "T"," "
        $global:lockto                      =   getDateString (get-date).AddDays(1) "T"
        $lockto                             =   $global:lockto -replace "T"," "        
        $global:UseRAServer                 =   $UseRAServer
        $global:sch_j_lock                  =   $false
        #regular expressions
        $global:rx_guid                     =   "\w{8}\-\w{4}\-\w{4}\-\w{4}\-\w{12}"
        $global:rx_ib_guid_part             =   "($global:rx_guid)[^:]+\:\s*"
        $global:rx_sesn_guid                =   "session[^:]+\:\s*($global:rx_guid)"
        $global:rx_sspr_guids               =   "connection[^:]+\:\s*($global:rx_guid)[\S\s]+?process[^:]+\:\s*($global:rx_guid)"
        $global:rx_infb_sch_j               =   "scheduled\-jobs\-deny[^:]+:\s*(on|off)"        
    }
    $unsafeActionsApplied                   =   $false
    # 1.2 Установка необязательных параметров
    if(!$TargetBasePort){
        $script:TargetBasePort              =   "1541"
    }
    if(!$TargetBaseAgentPort){
        $script:TargetBaseAgentPort         =   "1540"
    }

    if(!$PermissionCode){
        $script:PermissionCode              =   Get-Random -Minimum 1000000 -Maximum 9999999
    }
    chk4fileParam $WorkloadBeforeUpdatePath '$WorkloadBeforeUpdatePath' 'Обработка до выполнения'
    chk4fileParam $WorkloadAfterUpdatePath  '$WorkloadAfterUpdatePath' 'Обработка после выполнения'
    # либо обновляем из хранилища, либо из файла
    if ($ApplyCFPath){
        chk4fileParam $ApplyCFPath              '$ApplyCFPath'
    }    
    # 1.3 Проверка наличия файлов осуществляется в chk4fileParam    
    log_w "Исполняемый файл 1С              =   $run1c"
    if($UseRAServer -and $rac -and (chk4fileParam $rac 'RASClient')){
        $global:rac                         =   $rac
        log_w "Исполняемый файл 1С rac          =   $global:rac"        
    }
    log_w "Файл конфигурации 1С             =   $conf_cfg"
    log_w "Целевая база                     =   $TargetBase"
    log_w "Целевая база расположена         =   $TargetBaseServer`:$TargetBasePort"
    if(!$BaseUser){ 
        $BaseUser                           =   ""
        log_w "Имя пользователя не указано, используется доменная авторизация"
    }else{
        log_w `
          "Подключаемся под пользователем   =   $BaseUser"
    }
    if(!$BaseUserPass){
        $BaseUserPass                       =   ""
    }
    if($ApplyCFPath){
        log_w "Загружаем конфигурацию из файла $ApplyCFPath"
        if($ConfigurationRepositoryF){
            $ConfigurationRepositoryF       =   $null
        }
    }
    if($ConfigurationRepositoryF){
        log_w "Обновляем из хранилища           =   $ConfigurationRepositoryF"
        if(!$ConfigurationRepositoryN){
            $ConfigurationRepositoryN       =   ""
            log_w "Имя пользователя хранилища не указано"
        }else{
            log_w `
            "Подключаемся к хранилищу под     =   $ConfigurationRepositoryN"
        }
        if(!$ConfigurationRepositoryP){
            $ConfigurationRepositoryP       =   ""
        }
    }    
    if($ConfigurationRepositoryExtension){
        $Extension                          =   " -Extension $ConfigurationRepositoryExtension"
    }elseif($Extension){
        $Extension                          =   " -Extension $Extension"
    }else{
        $Extension                          =   ""
    }
    if($Extension){
        log_w("Работаем с расширением           =   " + $Extension).Replace(" -Extension ","")
    }

    log_w "Код блокировки                   =   $PermissionCode"
    if(!$LockMessage){
        $lockMessage                        =   "База заблокирована для обновления"
    }
    $global:lockmessage                     =   "$lockmessage. Время блокировки: с $lockfrom по $lockto"    
    if($ApplyCFPath){
        log_w `
         "Путь к загружаемой конфигурации  =   $ApplyCFPath"                                       # боль, маленькая ф в UTF-8 файле ломает powershell
    }
    if($WorkloadBeforeUpdatePath){
        log_w `
          "Выполняем перед обновлением      =   $WorkloadBeforeUpdatePath"                          #
    }
    if($WorkloadAfterUpdatePath){
        log_w `
          "Выполняем после обновлениея      =   $WorkloadAfterUpdatePath"                           #
    }
    $ScheduledJobsDenied                    =   [bool](GetScheduledJobsDeniedState  -BBBase $TargetBase `
                                                                                    -BBpermissionCode $PermissionCode  `
                                                                                    -BBServer $TargetBaseServer `
                                                                                    -BBAgentPort $TargetBaseAgentPort `
                                                                                    -BBBaseUser $BaseUser `
                                                                                    -BBBasePass $BaseUserPass)    

    log_w "Блокировка РЗ включена           =   $ScheduledJobsDenied"
    if($UpdateByClientInTheEnd){
        log_w "В самом конце запущу /C ЗапуститьОбновлениеИнформационнойБазы"
    }
    # 2.Блокировка базы
    # 2.0 Текущий статус блокировки РЗ
    # 2.1 Установка кода разрешения
    # 2.2 Блокировка ФЗ    
    log_w "Блокирую базу $TargetBase"
    $ret                                    =   [bool](LockBase -BBBase $TargetBase `
                                                                -BBpermissionCode $PermissionCode  `
                                                                -BBServer $TargetBaseServer `
                                                                -BBAgentPort $TargetBaseAgentPort `
                                                                -BBBaseUser $BaseUser `
                                                                -BBBasePass $BaseUserPass)                                                           
    log_w "Блокировка $TargetBase завершена. Результат выполнения - $ret"
    if(!$ret){
        log_w "Я дико извиняюсь, но продолжать не стану/"
        Exit 12
    }
    # 2.3 Блокировка базы
    log_w "Завершаю все сессии в базе $TargetBase"    
    $ret                                    =   KillSession -BBBase $TargetBase -BBConnectionString "$TargetBaseServer`:$TargetBaseAgentPort"
    log_w "У меня получилось=$ret завершить все сессии пользователей в  $TargetBase"
    if(!$ret){
        log_w "Это фиаску, ушёл топиться"
        Exit 13
    }

    $rand                                   =   Get-Random
    $log1C_file                             =   (split-path $MyInvocation.PSCommandPath -Leaf)+"."+$rand+".1c.log"
    if($BaseUser){
        $auth                               =   " /N`"$BaseUser`" /P`"$BaseUserPass`" "
    }else{
        $auth                               =   ""
    }
    $main_part                              =   "/S`"$TargetBaseServer`:$TargetBasePort`\$TargetBase`" `
                                                /UC$PermissionCode`
                                                $auth`
                                                /DisableStartupMessages`
                                                /Out`"$log1C_file`""
    $close_1c_workload                      =   (split-path $MyInvocation.PSCommandPath -Leaf)+".close1c.epf"
    $load_update_cfg                        =   "DESIGNER   $main_part /LoadCfg `"$ApplyCFPath`" $Extension /UpdateDBCfg" -replace "\s+"," "
    $applyWorkloadBefore                    =   "ENTERPRISE $main_part /Execute`"$WorkloadBeforeUpdatePath`"" -replace "\s+"," "
    $applyWorkloadAfter                     =   "ENTERPRISE $main_part /Execute`"$WorkloadAfterUpdatePath`"" -replace "\s+"," "
    $update_by_client                       =   "ENTERPRISE $main_part /C`"ЗапуститьОбновлениеИнформационнойБазы ВыполнитьОтложенноеОбновлениеСейчас ЗавершитьРаботуСистемы`" /Execute`"$close_1c_workload`"" -replace "\s+"," "
    $update_cfg_from_repo                   =   "DESIGNER   $main_part /ConfigurationRepositoryUpdateCfg -revised -force $Extension `
                                                /ConfigurationRepositoryF`"$ConfigurationRepositoryF`" `
                                                /ConfigurationRepositoryN`"$ConfigurationRepositoryN`" `
                                                /ConfigurationRepositoryP`"$ConfigurationRepositoryP`" /UpdateDBCfg" -replace "\s+"," "
        
    # отключаем обработку опасных действий, если будем использовать обработки
    if ($UpdateByClientInTheEnd -or $WorkloadBeforeUpdatePath -or $WorkloadAfterUpdatePath){
        $unsafeActionsApplied               =   enableUnsafeActions $conf_cfg
    }
    # 3.Выполнение обработки перед обновлением
    if($WorkloadBeforeUpdatePath){
        log_w "Processing $applyWorkloadBefore"
        run_me -run_exe $run1c -run_args $applyWorkloadBefore -log_text "Executing $run1c $applyWorkloadBefore" -log_file $log1C_file
        log_w "Ну, значит. Подготовились с помощью $WorkloadBeforeUpdatePath"
    }
    # 4.Обновление и применение конфы
    if($ConfigurationRepositoryF){
        # 4.2 Обновление и применение конфы из хранилища
        log_w "Processing $update_cfg_from_repo"
        run_me -run_exe $run1c -run_args $update_cfg_from_repo -log_text "Обновляю и применяю конфигурацию из хранилища $run1c $update_cfg_from_repo" -log_file $log1C_file
        log_w "Сам от себя такого не ожидал."
    }
    if($ApplyCFPath){
        # 4.1 Обновление и применение конфы из файла
        log_w "Processing $load_update_cfg"
        run_me -run_exe $run1c -run_args $load_update_cfg -log_text "Загружаю и применяю конфигурацию из $ApplyCFPath" -log_file $log1C_file
        log_w "Пока всё идёт по плану."
    }
    # 5.Выполнение после обновления
    if($WorkloadAfterUpdatePath){
        log_w "Processing $applyWorkloadAfter"
        run_me -run_exe $run1c -run_args $applyWorkloadAfter -log_text "Executing $applyWorkloadAfter" -log_file $log1C_file
        log_w "А напоследок поработает $WorkloadAfterUpdatePath"
    }
    # 5.2 Если указано, то /C ЗапуститьОбновлениеИнформационнойБазы
    if($UpdateByClientInTheEnd){
        log_w "Processing $update_by_client"
        run_me -run_exe $run1c -run_args $update_by_client -log_text "Выполняю /C ЗапуститьОбновлениеИнформационнойБазы" -log_file $log1C_file
    }
    # 6.Разблокировка базы
    log_w "Уже почти всё. Сейчас разрешу пользователям и фоновым заданиям работать в $TargetBase"
    # возврат conf.cfg
    if($unsafeActionsApplied -eq $true){
        disableUnsafeActions $conf_cfg
    }
    $ret                                    =   [bool](UnlockBase   -BBBase $TargetBase `
                                                                    -BBpermissionCode $PermissionCode `
                                                                    -BBServer $TargetBaseServer `
                                                                    -BBAgentPort $TargetBaseAgentPort `
                                                                    -BBBaseUser $BaseUser `
                                                                    -BBBasePass $BaseUserPass,
                                                                    -BBUnlockJobs $ScheduledJobsDenied)
    log_w "Могут ли пользователя работать в  $TargetBase. Ответ - $ret"
    Remove-Item -Path $log1C_file
    if($ret){
        log_w "Да! Я снова сделал это!"
        Exit 0
    }else{
        log_w "Неееееееееееееееееет, такой фейл на последнем метре... Надо звать человеков на помощь"
        Exit 14
    }
}
main