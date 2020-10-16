powershell -NoProfile -File c:\dev\C1Updater\C1Updater.ps1 ^
-TargetBase basename ^
-TargetBaseServer serv ^
-TargetBasePort 1541 ^
-TargetBaseAgentPort 1540 ^
-ApplyCFPath c:\1C\1cfv.cf ^
-PermissionCode 1 ^
-WorkloadBeforeUpdatePath c:\1C\DistributedInfoBase_OFF.epf ^
-WorkloadAfterUpdatePath c:\1C\DistributedInfoBase_ON.epf ^
-BaseUser user ^
-BaseUserPass pwd
rem -BaseUser 